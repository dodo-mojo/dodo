// Parse JSON with simdjson and lay the document out as a dodo.json tape.
//
// The Mojo side (simdjson.mojo) calls three functions: get this thread's
// parser, parse into the tape, and read the addresses of the result
// buffers. Strings and keys are unescaped into one arena that the tape
// slices by (offset, length), so Mojo copies five flat buffers and nothing
// per value.

// <iterator> must precede <simdjson.h>: simdjson 4.6.11 uses std::inserter
// without including it, which libc++ (macOS) does not provide on its own.
#include <iterator>

#include <simdjson.h>

#include <pthread.h>

#include <cstdint>
#include <cstring>
#include <string>
#include <string_view>
#include <vector>

#include "../../utils/ffi/pin_self.h"

namespace {

// Result codes. simdjson.mojo only checks for RESULT_OK.
constexpr int RESULT_OK = 0;
constexpr int RESULT_INVALID_JSON = 1;
constexpr int RESULT_CAPACITY = 2;
constexpr int RESULT_INVALID_UTF8 = 3;
constexpr int RESULT_OTHER = 99;

// Tape layout, mirrored in document.mojo: a 4-bit tag over a 60-bit
// payload, a pair is two 30-bit halves, and a container's children precede
// its header.
constexpr uint64_t TAG_NULL = 0, TAG_BOOL = 1, TAG_INT = 2, TAG_FLOAT = 3,
                   TAG_STRING = 4, TAG_ARRAY = 5, TAG_OBJECT = 6,
                   TAG_KEY_INLINE = 9, TAG_INT_POOL = 10, TAG_UINT = 11;
constexpr uint64_t PAYLOAD_MASK = (uint64_t(1) << 60) - 1;
constexpr uint64_t HALF_MASK = (uint64_t(1) << 30) - 1;
constexpr int64_t INLINE_INT_LIMIT = int64_t(1) << 59;

struct ParserState {
    simdjson::dom::parser parser;
    std::vector<uint64_t> tape;
    std::vector<uint64_t> scratch;
    std::string arena;
    std::vector<double> floats;
    std::vector<int64_t> ints;
};

// Thrown when an offset or count no longer fits in 30 bits.
struct TapeTooLarge {};

uint64_t entry(uint64_t tag, uint64_t payload) {
    return (tag << 60) | (payload & PAYLOAD_MASK);
}

uint64_t pair(uint64_t high, uint64_t low) {
    return ((high & HALF_MASK) << 30) | (low & HALF_MASK);
}

uint64_t slice(ParserState& state, std::string_view text, uint64_t tag) {
    uint64_t offset = state.arena.size();
    if (offset > HALF_MASK || text.size() > HALF_MASK ||
        offset + text.size() > HALF_MASK) {
        throw TapeTooLarge{};
    }
    state.arena.append(text.data(), text.size());
    return entry(tag, pair(offset, text.size()));
}

// Moves the children collected in `scratch` since `base` onto the tape and
// returns the tape index of the first one.
uint64_t flush_children(ParserState& state, size_t base) {
    uint64_t start = state.tape.size();
    state.tape.insert(
        state.tape.end(), state.scratch.begin() + base, state.scratch.end());
    state.scratch.resize(base);
    return start;
}

uint64_t emit(ParserState& state, simdjson::dom::element element) {
    using simdjson::dom::element_type;
    switch (element.type()) {
    case element_type::NULL_VALUE:
        return entry(TAG_NULL, 0);
    case element_type::BOOL:
        return entry(TAG_BOOL, bool(element.get_bool().value_unsafe()) ? 1 : 0);
    case element_type::INT64: {
        int64_t value = element.get_int64().value_unsafe();
        if (value >= -INLINE_INT_LIMIT && value < INLINE_INT_LIMIT) {
            return entry(TAG_INT, uint64_t(value));
        }
        state.ints.push_back(value);
        return entry(TAG_INT_POOL, state.ints.size() - 1);
    }
    case element_type::UINT64: {
        uint64_t value = element.get_uint64().value_unsafe();
        int64_t bits;
        std::memcpy(&bits, &value, sizeof bits);
        state.ints.push_back(bits);
        return entry(TAG_UINT, state.ints.size() - 1);
    }
    case element_type::DOUBLE:
        state.floats.push_back(element.get_double().value_unsafe());
        return entry(TAG_FLOAT, state.floats.size() - 1);
    case element_type::STRING:
        return slice(state, element.get_string().value_unsafe(), TAG_STRING);
    case element_type::ARRAY: {
        size_t base = state.scratch.size();
        uint64_t count = 0;
        simdjson::dom::array array = element.get_array().value_unsafe();
        for (auto child : array) {
            state.scratch.push_back(emit(state, child));
            ++count;
        }
        uint64_t start = flush_children(state, base);
        if (count > HALF_MASK || start > HALF_MASK) {
            throw TapeTooLarge{};
        }
        return entry(TAG_ARRAY, pair(count, start));
    }
    case element_type::OBJECT: {
        size_t base = state.scratch.size();
        uint64_t count = 0;
        simdjson::dom::object object = element.get_object().value_unsafe();
        for (auto field : object) {
            uint64_t key = slice(state, field.key, TAG_KEY_INLINE);
            uint64_t value = emit(state, field.value);
            state.scratch.push_back(key);
            state.scratch.push_back(value);
            ++count;
        }
        uint64_t start = flush_children(state, base);
        if (count > HALF_MASK || start > HALF_MASK) {
            throw TapeTooLarge{};
        }
        return entry(TAG_OBJECT, pair(count, start));
    }
    default:
        break;
    }
    return entry(TAG_NULL, 0);
}

// A pthread key rather than thread_local: this library is loaded with
// dlopen, and a TLS segment in it would bump glibc's TLS generation and
// leave every other library's dynamic TLS access (the host's allocator
// included) on __tls_get_addr's slow path.
pthread_key_t parser_key;
pthread_once_t parser_key_once = PTHREAD_ONCE_INIT;

void create_parser_key() {
    pthread_key_create(&parser_key, [](void* state) {
        delete static_cast<ParserState*>(state);
    });
}

int result_code(simdjson::error_code error) {
    if (error == simdjson::CAPACITY) {
        return RESULT_CAPACITY;
    }
    if (error == simdjson::UTF8_ERROR) {
        return RESULT_INVALID_UTF8;
    }
    return RESULT_INVALID_JSON;
}

}  // namespace

extern "C" {

// The calling thread's parser, created on first use and kept for the
// thread's lifetime so its buffers are reused across parses.
void* dodo_simdjson_thread_parser(void) {
    pthread_once(&parser_key_once, create_parser_key);
    void* existing = pthread_getspecific(parser_key);
    if (existing != nullptr) {
        return existing;
    }
    auto* state = new ParserState();
    pthread_setspecific(parser_key, state);
    return state;
}

// Parses `json` (any bytes; simdjson copies them into a padded buffer) and
// fills the parser's tape buffers. Returns a RESULT_* code.
int dodo_simdjson_parse_to_tape(void* parser, const char* json, size_t length) {
    if (parser == nullptr || json == nullptr) {
        return RESULT_OTHER;
    }
    auto* state = static_cast<ParserState*>(parser);
    auto result = state->parser.parse(json, length, true);
    if (result.error()) {
        return result_code(result.error());
    }
    state->tape.clear();
    state->scratch.clear();
    state->arena.clear();
    state->floats.clear();
    state->ints.clear();
    try {
        uint64_t root = emit(*state, result.value());
        state->tape.push_back(root);
    } catch (const TapeTooLarge&) {
        return RESULT_CAPACITY;
    }
    return RESULT_OK;
}

// out[0..8): tape ptr, tape len, arena ptr, arena len, floats ptr, floats
// len, ints ptr, ints len. Valid until the next parse on this parser.
void dodo_simdjson_tape_buffers(void* parser, int64_t* out) {
    auto* state = static_cast<ParserState*>(parser);
    out[0] = int64_t(reinterpret_cast<intptr_t>(state->tape.data()));
    out[1] = int64_t(state->tape.size());
    out[2] = int64_t(reinterpret_cast<intptr_t>(state->arena.data()));
    out[3] = int64_t(state->arena.size());
    out[4] = int64_t(reinterpret_cast<intptr_t>(state->floats.data()));
    out[5] = int64_t(state->floats.size());
    out[6] = int64_t(reinterpret_cast<intptr_t>(state->ints.data()));
    out[7] = int64_t(state->ints.size());
}

// Copies `count` bytes from the address `source` to `destination`, so Mojo
// need not turn an integer into a pointer.
void dodo_simdjson_copy(void* destination, intptr_t source, size_t count) {
    std::memcpy(destination, reinterpret_cast<const void*>(source), count);
}

}  // extern "C"
