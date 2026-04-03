;; inject SQL into any Python string containing SQL keywords
; (expression_statement
;   (assignment
;     right: (string) @sql (#match? @sql "SELECT|FROM|WHERE"))
; )

(expression_statement
  (assignment
    right: (string
      (string_content) @injection.content
      (#match? @injection.content "SELECT|FROM|WHERE")
      (#set! injection.language "sql")
      (#set! injection.include-children))
))
