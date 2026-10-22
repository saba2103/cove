# Component specs

One file per primitive. Each is the contract for a widget in `lib/core/widgets/`.

**Every number here is DEVICE scale (dp), already converted from the prototype.**
The prototype is 300×682px of content; device is anchored at 393dp. Factor 1.3, snapped
to multiples of four. Prototype pixel values never appear in this repo — if you find
yourself reading 16 where this says 20, you are looking at the wrong source.

**Prefer the token name over the number.** Where a spec says `CoveSpace.gutter`, write
`CoveSpace.gutter`, not `20`. Raw numbers appear only where no token covers the value,
and those are marked `(literal)`.

Measured from "Cove, Put Together" V74 in a browser, not read off a design file.
