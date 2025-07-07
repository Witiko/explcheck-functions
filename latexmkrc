# Custom latexmk configuration
## Output PDF by default and set default engine to LuaLaTeX.
$pdf_mode = 4;

## Enable shell escape.
set_tex_cmds('--shell-escape %O %S');

## Treat warnings as errors
$warnings_as_errors = 1;
