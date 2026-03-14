;;; nih-grant-setup.el --- NIH Grant Proposal Configuration for Org-mode -*- lexical-binding: t; -*-

;; Author: Sanjay
;; Version: 2.1
;; Package-Requires: ((emacs "27.1") (org "9.5"))
;; Keywords: org, latex, nih, grants
;; URL: https://grants.nih.gov/grants-process/write-application

;;; Commentary:

;; Portable NIH grant writing support for Org-mode.
;;
;; Features:
;; - NIH-compliant PDF export via XeLaTeX
;; - DOCX export via Pandoc for collaboration
;; - Page limit tracking for all grant types
;; - Templates for R01, R21, F31, F32, K99, etc.
;;
;; External Dependencies (checked at runtime):
;; - xelatex (texlive-xetex) for PDF export
;; - pandoc for DOCX export
;; - Liberation Sans font (or configure nih-grant-font)
;;
;; NIH Formatting Requirements (Updated January 2026):
;; - Font: 11pt minimum (Arial, Georgia, Helvetica, Palatino Linotype)
;; - Margins: 0.5 inch minimum on all sides
;; - Type density: <=15 characters per linear inch
;; - Line spacing: <=6 lines per vertical inch
;; - No headers/footers (NIH adds these upon submission)
;;
;; Reference: https://grants.nih.gov/grants-process/write-application/how-to-apply-application-guide/format-attachments

;;; Code:

(require 'org)
(require 'ox-latex)

;;;; ============================================================
;;;;                    CUSTOMIZATION
;;;; ============================================================

(defgroup nih-grant nil
  "NIH grant writing support for Org-mode."
  :group 'org
  :prefix "nih-grant-")

(defcustom nih-grant-type 'r01
  "Current NIH grant type for page limit checking."
  :type '(choice (const :tag "R01 - Research Project" r01)
                 (const :tag "R03 - Small Grant" r03)
                 (const :tag "R21 - Exploratory/Developmental" r21)
                 (const :tag "K01 - Mentored Research Scientist" k01)
                 (const :tag "K99/R00 - Pathway to Independence" k99)
                 (const :tag "F31 - Predoctoral Fellowship" f31)
                 (const :tag "F32 - Postdoctoral Fellowship" f32))
  :group 'nih-grant)

(defcustom nih-grant-font nil
  "Font to use for NIH grants.
If nil, auto-detects from available fonts.
NIH-approved options: Arial, Georgia, Helvetica, Palatino Linotype.
Liberation Sans and DejaVu Sans are open-source alternatives."
  :type '(choice (const :tag "Auto-detect" nil)
                 (string :tag "Font name"))
  :group 'nih-grant)

(defcustom nih-grant-words-per-page-text-only 700.0
  "Estimated words per page for text-only content at 11pt."
  :type 'float
  :group 'nih-grant)

(defcustom nih-grant-words-per-page-with-figs 500.0
  "Estimated words per page for content with figures/tables."
  :type 'float
  :group 'nih-grant)

(defcustom nih-grant-draft-mode t
  "When non-nil, include draft watermark on pages.
Set to nil before final export for submission."
  :type 'boolean
  :group 'nih-grant)

(defcustom nih-grant-auto-view-pdf t
  "When non-nil, automatically open PDF after export."
  :type 'boolean
  :group 'nih-grant)

(defcustom nih-grant-pdf-viewer 'system
  "How to view exported PDFs.
`emacs' uses pdf-tools or doc-view inside Emacs.
`system' uses the system default PDF viewer."
  :type '(choice (const :tag "View in Emacs (pdf-tools/doc-view)" emacs)
                 (const :tag "System default viewer" system))
  :group 'nih-grant)

;;;; ============================================================
;;;;                    PAGE LIMITS (January 2026)
;;;; ============================================================
;; Source: https://grants.nih.gov/grants-process/write-application/how-to-apply-application-guide/page-limits

(defconst nih-grant-page-limits
  '((r01 . (("Specific Aims" . 1)
            ("Research Strategy" . 12)
            ("Introduction" . 1)))
    (r03 . (("Specific Aims" . 1)
            ("Research Strategy" . 6)
            ("Introduction" . 1)))
    (r21 . (("Specific Aims" . 1)
            ("Research Strategy" . 6)
            ("Introduction" . 1)))
    (k01 . (("Specific Aims" . 1)
            ("Candidate Information and Goals for Career Development" . 12)
            ("Mentoring Plan" . 6)
            ("Introduction" . 1)))
    (k99 . (("Specific Aims" . 1)
            ("Candidate Information and Goals for Career Development" . 12)
            ("Mentoring Plan" . 6)
            ("Introduction" . 1)))
    (f31 . (("Specific Aims" . 1)
            ("Research Training Project Strategy" . 6)
            ("Candidate's Goals, Preparedness, and Potential" . 3)
            ("Introduction" . 1)))
    (f32 . (("Specific Aims" . 1)
            ("Research Training Project Strategy" . 6)
            ("Candidate's Goals, Preparedness, and Potential" . 3)
            ("Introduction" . 1))))
  "Page limits for different NIH grant types.")

;;;; ============================================================
;;;;                    FONT DETECTION
;;;; ============================================================

(defun nih-grant--detect-font ()
  "Detect an available NIH-compatible font."
  (or nih-grant-font
      (let ((candidates '("Arial" "Liberation Sans" "Helvetica" "Helvetica Neue"
                          "DejaVu Sans" "Georgia" "Palatino Linotype")))
        (if (display-graphic-p)
            (cl-loop for font in candidates
                     when (member font (font-family-list))
                     return font
                     finally return "DejaVu Sans")
          ;; In terminal, just use a common font name
          "DejaVu Sans"))))

;;;; ============================================================
;;;;                    LATEX DOCUMENT CLASS
;;;; ============================================================

(defun nih-grant--generate-preamble ()
  "Generate LaTeX preamble based on current settings."
  (let ((font (nih-grant--detect-font)))
    (format "\\documentclass[11pt,letterpaper]{article}
\\usepackage[margin=0.5in]{geometry}
\\usepackage{fontspec}
\\setmainfont{%s}
\\usepackage{setspace}
\\usepackage{titlesec}
\\usepackage{graphicx}
\\usepackage{xcolor}
\\usepackage{hyperref}
\\hypersetup{colorlinks=true,linkcolor=blue,urlcolor=blue,citecolor=blue}

%% Text formatting
\\setstretch{1.0}
\\setlength{\\parskip}{0.5ex}
\\setlength{\\parindent}{0pt}

%% Section formatting
\\titleformat{\\section}{\\normalfont\\normalsize\\bfseries}{}{0em}{}
\\titlespacing*{\\section}{0pt}{1.5ex plus 0.5ex minus 0.2ex}{0.5ex plus 0.2ex}
\\titleformat{\\subsection}{\\normalfont\\normalsize\\bfseries}{}{0em}{}
\\titlespacing*{\\subsection}{0pt}{1ex plus 0.3ex minus 0.1ex}{0.3ex plus 0.1ex}
\\titleformat{\\subsubsection}{\\normalfont\\normalsize\\itshape}{}{0em}{}
\\titlespacing*{\\subsubsection}{0pt}{0.8ex plus 0.2ex}{0.2ex}

%% Figure and table captions
\\usepackage[font=small,labelfont=bf]{caption}

%% Draft mode watermark
%s

%% Remove page numbers (NIH adds them)
\\pagenumbering{gobble}

[NO-DEFAULT-PACKAGES]
[PACKAGES]
[EXTRA]"
            font
            (if nih-grant-draft-mode
                "\\usepackage{fancyhdr}
\\usepackage{lastpage}
\\pagestyle{fancy}
\\fancyhf{}
\\renewcommand{\\headrulewidth}{0pt}
\\cfoot{\\textcolor{red}{\\footnotesize [DRAFT - Page \\thepage\\ of \\pageref{LastPage} - Remove before submission]}}"
              ""))))

(defun nih-grant-setup-latex-class ()
  "Set up the NIH grant LaTeX class with current settings."
  (setq org-latex-classes
        (assoc-delete-all "nih-grant" org-latex-classes))
  (add-to-list 'org-latex-classes
               `("nih-grant"
                 ,(nih-grant--generate-preamble)
                 ("\\section{%s}" . "\\section*{%s}")
                 ("\\subsection{%s}" . "\\subsection*{%s}")
                 ("\\subsubsection{%s}" . "\\subsubsection*{%s}")
                 ("\\paragraph{%s}" . "\\paragraph*{%s}"))))

;; Initialize the class
(nih-grant-setup-latex-class)

;;;; ============================================================
;;;;                    PDF EXPORT
;;;; ============================================================

(defun nih-grant--view-file (file)
  "View FILE according to `nih-grant-pdf-viewer' setting."
  (when (and nih-grant-auto-view-pdf (file-exists-p file))
    (pcase nih-grant-pdf-viewer
      ('emacs (find-file-other-window file))
      ('system
       (pcase system-type
         ('darwin (call-process "open" nil 0 nil file))
         ('gnu/linux (call-process "xdg-open" nil 0 nil file))
         ('windows-nt (call-process "cmd" nil 0 nil "/c" "start" "" file)))))))

(defun nih-export-to-pdf ()
  "Export current Org buffer to NIH-formatted PDF."
  (interactive)
  (unless (executable-find "xelatex")
    (user-error "XeLaTeX not found. Install texlive-xetex for PDF export"))
  (nih-grant-setup-latex-class)
  ;; Use let-binding to avoid changing global settings
  (let* ((org-latex-pdf-process
          '("xelatex -interaction nonstopmode -output-directory %o %f"
            "xelatex -interaction nonstopmode -output-directory %o %f"))
         (org-latex-title-command "")
         (org-latex-toc-command "")
         (org-export-with-author nil)
         (org-export-with-date nil)
         (org-export-with-toc nil)
         (org-export-with-title nil)
         (pdf-file (org-latex-export-to-pdf)))
    (when pdf-file
      (nih-grant--view-file pdf-file)
      (message "Exported to PDF%s" (if nih-grant-draft-mode " (DRAFT)" "")))))

(defun nih-export-final ()
  "Export for final submission (no draft watermark)."
  (interactive)
  (let ((nih-grant-draft-mode nil))
    (nih-grant-setup-latex-class)
    (nih-export-to-pdf)
    (message "Exported FINAL version for submission")))

(defun nih-view-pdf ()
  "View the PDF for the current Org file."
  (interactive)
  (let ((pdf-file (concat (file-name-sans-extension (buffer-file-name)) ".pdf")))
    (if (file-exists-p pdf-file)
        (nih-grant--view-file pdf-file)
      (user-error "PDF not found. Export first with C-c g e"))))

;;;; ============================================================
;;;;                    DOCX EXPORT
;;;; ============================================================

(defun nih-grant--pandoc-reference-doc ()
  "Return path to NIH reference DOCX template if it exists."
  (let ((ref-doc (expand-file-name "nih-reference.docx" user-emacs-directory)))
    (when (file-exists-p ref-doc)
      ref-doc)))

(defun nih-export-to-docx ()
  "Export current Org buffer to NIH-formatted DOCX via Pandoc."
  (interactive)
  (unless (executable-find "pandoc")
    (user-error "Pandoc not found. Install pandoc for DOCX export"))
  (let* ((org-file (buffer-file-name))
         (docx-file (concat (file-name-sans-extension org-file) ".docx"))
         (ref-doc (nih-grant--pandoc-reference-doc))
         (cmd (concat "pandoc "
                      (shell-quote-argument org-file)
                      " -f org -t docx"
                      " --wrap=none"
                      (if ref-doc
                          (concat " --reference-doc=" (shell-quote-argument ref-doc))
                        "")
                      " -o " (shell-quote-argument docx-file))))
    (message "Exporting to DOCX...")
    (if (zerop (call-process-shell-command cmd))
        (progn
          (message "Exported to %s" docx-file)
          (when nih-grant-auto-view-pdf
            (nih-grant--view-file docx-file)))
      (user-error "Pandoc export failed. Check *Messages* buffer"))))

(defun nih-create-reference-docx ()
  "Create an NIH-formatted reference DOCX template.
This template will be used for all future DOCX exports."
  (interactive)
  (unless (executable-find "pandoc")
    (user-error "Pandoc not found"))
  (let ((ref-doc (expand-file-name "nih-reference.docx" user-emacs-directory))
        (temp-org (make-temp-file "nih-ref-" nil ".org")))
    (with-temp-file temp-org
      (insert "#+TITLE: Reference\n* Heading\nParagraph text.\n** Subheading\nMore text."))
    (call-process-shell-command
     (format "pandoc %s -f org -t docx -o %s"
             (shell-quote-argument temp-org)
             (shell-quote-argument ref-doc)))
    (delete-file temp-org)
    (message "Reference DOCX created at %s
Open in Word/LibreOffice, set Arial 11pt and 0.5\" margins, then save." ref-doc)
    (nih-grant--view-file ref-doc)))

;;;; ============================================================
;;;;                    WORD COUNT & PAGE LIMITS
;;;; ============================================================

(defun nih-word-count ()
  "Count words in current subtree and estimate pages."
  (interactive)
  (save-excursion
    (save-restriction
      (org-narrow-to-subtree)
      (let* ((words (count-words (point-min) (point-max)))
             (pages-text (/ (float words) nih-grant-words-per-page-text-only))
             (pages-figs (/ (float words) nih-grant-words-per-page-with-figs)))
        (message "Words: %d | Est. pages (text): %.2f | Est. pages (w/figures): %.2f"
                 words pages-text pages-figs)))))

(defun nih-grant--get-section-limit (heading)
  "Get page limit for HEADING based on current grant type."
  (let* ((limits (cdr (assoc nih-grant-type nih-grant-page-limits)))
         (clean-heading (replace-regexp-in-string
                         "^\\*+ *\\(?:TODO\\|DONE\\|NEXT\\|WAITING\\|TOREAD\\|READING\\|PAUSED\\|ABORTED\\) *" ""
                         (replace-regexp-in-string " *:[^:]+:$" "" heading))))
    (cdr (assoc clean-heading limits))))

(defun nih-check-page-limits ()
  "Check if current section exceeds NIH page limits."
  (interactive)
  (let* ((heading (org-get-heading t t t t))
         (limit (nih-grant--get-section-limit heading)))
    (if limit
        (save-excursion
          (save-restriction
            (org-narrow-to-subtree)
            (let* ((words (count-words (point-min) (point-max)))
                   (pages (/ (float words) nih-grant-words-per-page-with-figs)))
              (if (> pages limit)
                  (message "WARNING: %s: %.2f pages (limit: %d) - OVER BY %.2f pages"
                           heading pages limit (- pages limit))
                (message "OK: %s: %.2f pages (limit: %d) - %.2f pages remaining"
                         heading pages limit (- limit pages))))))
      (message "No page limit defined for '%s' in %s grants" heading nih-grant-type))))

(defun nih-check-all-limits ()
  "Check page limits for all sections in the document."
  (interactive)
  (let ((results '())
        (over-limit nil))
    (org-map-entries
     (lambda ()
       (let* ((heading (org-get-heading t t t t))
              (limit (nih-grant--get-section-limit heading)))
         (when limit
           (save-excursion
             (save-restriction
               (org-narrow-to-subtree)
               (let* ((words (count-words (point-min) (point-max)))
                      (pages (/ (float words) nih-grant-words-per-page-with-figs))
                      (status (if (> pages limit) "OVER" "OK")))
                 (when (> pages limit) (setq over-limit t))
                 (push (format "  %s: %.1f/%d pages [%s]" heading pages limit status)
                       results))))))))
    (message "=== %s Page Limit Check ===\n%s\n%s"
             (upcase (symbol-name nih-grant-type))
             (mapconcat #'identity (nreverse results) "\n")
             (if over-limit "WARNING: Some sections exceed limits!" "All sections within limits"))))

;;;; ============================================================
;;;;                    GRANT TYPE & TEMPLATES
;;;; ============================================================

(defun nih-set-grant-type ()
  "Interactively set the NIH grant type."
  (interactive)
  (let ((type (intern (completing-read
                       "Grant type: "
                       '("r01" "r03" "r21" "k01" "k99" "f31" "f32")
                       nil t))))
    (setq nih-grant-type type)
    (message "Grant type set to %s" (upcase (symbol-name type)))))

(defun nih-insert-template ()
  "Insert a template for the current grant type."
  (interactive)
  (let ((template
         (pcase nih-grant-type
           ((or 'r01 'r03 'r21)
            "#+TITLE: [Project Title]
#+LATEX_CLASS: nih-grant
#+OPTIONS: toc:nil author:nil date:nil title:nil

* Specific Aims
[1 page limit]

* Research Strategy
** Significance
[Describe importance of the problem]

** Innovation
[Explain novel aspects of your approach]

** Approach
[Detail your research plan]

*** Preliminary Studies
[Include relevant preliminary data]

*** Research Design
[Describe experimental approach]

*** Expected Outcomes
[Discuss anticipated results]

*** Potential Problems and Alternative Strategies
[Address possible challenges]

*** Timeline
[Provide milestones]
")
           ((or 'f31 'f32)
            "#+TITLE: [Fellowship Title]
#+LATEX_CLASS: nih-grant
#+OPTIONS: toc:nil author:nil date:nil title:nil

* Specific Aims
[1 page limit]

* Research Training Project Strategy
[6 page limit]

** Significance

** Innovation

** Approach

* Candidate's Goals, Preparedness, and Potential
[3 page limit]

** Goals

** Preparedness

** Potential
")
           ((or 'k01 'k99)
            "#+TITLE: [Career Development Title]
#+LATEX_CLASS: nih-grant
#+OPTIONS: toc:nil author:nil date:nil title:nil

* Specific Aims
[1 page limit]

* Candidate Information and Goals for Career Development
[12 pages combined with Research Strategy]

** Career Goals

** Training Goals

* Research Strategy

** Significance

** Innovation

** Approach
")
           (_
            "#+TITLE: [Grant Title]
#+LATEX_CLASS: nih-grant
#+OPTIONS: toc:nil author:nil date:nil title:nil

* Specific Aims
[1 page limit]
"))))
    (insert template)
    (goto-char (point-min))
    (search-forward "[" nil t)
    (message "Template inserted for %s" (upcase (symbol-name nih-grant-type)))))

;;;; ============================================================
;;;;                    MODE & KEYBINDINGS
;;;; ============================================================

(defun nih-toggle-draft-mode ()
  "Toggle draft mode on/off."
  (interactive)
  (setq nih-grant-draft-mode (not nih-grant-draft-mode))
  (nih-grant-setup-latex-class)
  (message "Draft mode %s" (if nih-grant-draft-mode "enabled" "disabled")))

(define-minor-mode nih-grant-mode
  "Minor mode for writing NIH grant proposals in Org-mode."
  :lighter " NIH"
  (when nih-grant-mode
    (message "NIH Grant mode enabled. C-c g ? for help.")))

(defun nih-grant-help ()
  "Display help for NIH grant mode keybindings."
  (interactive)
  (with-help-window "*NIH Grant Help*"
    (princ "NIH Grant Mode Keybindings
===========================

EXPORT
  C-c g e  Export to PDF (draft mode)
  C-c g f  Export final PDF (no watermark)
  C-c g x  Export to DOCX (for collaboration)
  C-c g v  View current PDF

PAGE TRACKING
  C-c g w  Word count for current section
  C-c g p  Check page limit for current section
  C-c g a  Check all sections against limits

SETUP
  C-c g t  Set grant type (R01, R21, F31, etc.)
  C-c g i  Insert template for current grant type
  C-c g d  Toggle draft mode on/off
  C-c g ?  Show this help

CURRENT SETTINGS
")
    (princ (format "  Grant type: %s\n" (upcase (symbol-name nih-grant-type))))
    (princ (format "  Draft mode: %s\n" (if nih-grant-draft-mode "ON" "OFF")))
    (princ (format "  PDF viewer: %s\n" nih-grant-pdf-viewer))
    (princ (format "  Font: %s\n" (nih-grant--detect-font)))
    (princ "\nFor DOCX with NIH formatting:
  M-x nih-create-reference-docx
  Then edit styles in Word/LibreOffice and save.")))

;; Bind keys to org-mode-map (available in all org buffers)
(with-eval-after-load 'org
  (define-key org-mode-map (kbd "C-c g e") #'nih-export-to-pdf)
  (define-key org-mode-map (kbd "C-c g f") #'nih-export-final)
  (define-key org-mode-map (kbd "C-c g x") #'nih-export-to-docx)
  (define-key org-mode-map (kbd "C-c g v") #'nih-view-pdf)
  (define-key org-mode-map (kbd "C-c g w") #'nih-word-count)
  (define-key org-mode-map (kbd "C-c g p") #'nih-check-page-limits)
  (define-key org-mode-map (kbd "C-c g a") #'nih-check-all-limits)
  (define-key org-mode-map (kbd "C-c g t") #'nih-set-grant-type)
  (define-key org-mode-map (kbd "C-c g i") #'nih-insert-template)
  (define-key org-mode-map (kbd "C-c g d") #'nih-toggle-draft-mode)
  (define-key org-mode-map (kbd "C-c g ?") #'nih-grant-help))

;; Auto-activate for grant files
(defun nih-grant--maybe-enable ()
  "Enable NIH grant mode if filename suggests it's a grant."
  (when (and (buffer-file-name)
             (string-match-p
              "\\(nih\\|grant\\|r01\\|r03\\|r21\\|k01\\|k99\\|f31\\|f32\\)"
              (downcase (buffer-file-name))))
    (nih-grant-mode 1)))

(add-hook 'org-mode-hook #'nih-grant--maybe-enable)

(provide 'nih-grant-setup)
;;; nih-grant-setup.el ends here
