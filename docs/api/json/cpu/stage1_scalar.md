# `dodo.json.cpu.stage1_scalar`

## Structs

### `StructuralIndex`

```mojo
struct StructuralIndex
```

Sorted list of structural-character offsets in the input.

`positions[i]` is the byte offset of the i-th structural character.
The list is strictly increasing.

Stage 2 traverses the positions in order; each position points at a
char in `{ } [ ] : , "` outside of any string literal (with both
opening and closing quotes recorded).

Fields:

- `positions` (`List[UInt32]`)

Implemented traits: `AnyType`, `Copyable`, `Deinitable`, `Movable`

#### `StructuralIndex.__init__`

```mojo
def __init__(out self, capacity: Int = Int(0))
```

#### `StructuralIndex.copy`

```mojo
def copy(self) -> Self
```

#### `StructuralIndex.size`

```mojo
def size(self) -> Int
```

## Functions

### `parse_structural_scalar`

```mojo
def parse_structural_scalar(input: String) -> StructuralIndex
```

Build a structural index by walking the input byte-by-byte.

Always succeeds: even malformed JSON produces *some* index, since
stage 1 only tracks string state. Errors surface in stage 2 when
the index is walked.

Args:

- `input`: Raw JSON bytes.

Returns: StructuralIndex with the offsets of all structural characters (`{` `}` `[` `]` `:` `,` `"`) that are not inside a string.
