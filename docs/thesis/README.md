Thesis LaTeX Template

Structure
- main.tex: Entry point. Edit title, author, date.
- titlepage.tex: Customize university, department, supervisors.
- abstract.tex, acknowledgements.tex: Fill in your text.
- chapters/: Edit and add chapters as needed.
- appendices/: Optional appendices.
- refs.bib: Add your BibTeX references.
- figures/: Place figures and diagrams here.

Compile (Windows)
1) Install a TeX distribution (MiKTeX or TeX Live) and a LaTeX editor (TeXworks, TeXstudio, or VS Code with LaTeX Workshop).
2) Open main.tex in your editor and build using pdflatex + biber + pdflatex + pdflatex (or use latexmk if available).

Export to Word (.docx)
- Install Pandoc (https://pandoc.org/installing.html). On Windows you can also use: winget install --id JohnMacFarlane.Pandoc -e
- Run build_word.bat or build_word.ps1. The output will be in output/thesis.docx.
	Notes: This uses pandoc’s LaTeX reader; not all LaTeX macros map 1:1 to Word, but the structure and content are preserved. Citations are rendered via citeproc.

Notes
- Replace placeholders (Your Name, University Name, Supervisor Name, Month Year).
- Adjust geometry margins or fonts to match your department’s template if required.
- If your thesis requires dual-language abstracts or specific front matter, add/modify sections accordingly.
