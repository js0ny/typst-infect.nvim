; extends

((latex_block
  (latex_span_delimiter) @_start
  (latex_span_delimiter) @_end) @image.content @image
  (#eq? @_start "$")
  (#eq? @_end "$")
  (#offset! @image.content 0 1 0 -1)
  (#set! image.lang "typst_infect")
  (#set! image.ext "math.typ"))

((latex_block
  (latex_span_delimiter) @_start
  (latex_span_delimiter) @_end) @image.content @image
  (#eq? @_start "$$")
  (#eq? @_end "$$")
  (#offset! @image.content 0 2 0 -2)
  (#set! image.lang "typst_infect")
  (#set! image.ext "math.typ"))
