;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Place your private configuration here! Remember, you do not need to run 'doom
;; sync' after modifying this file!


;; Some functionality uses this to identify you, e.g. GPG configuration, email
;; clients, file templates and snippets. It is optional.
;; (setq user-full-name "John Doe"
;;       user-mail-address "john@doe.com")

;; Doom exposes five (optional) variables for controlling fonts in Doom:
;;
;; - `doom-font' -- the primary font to use
;; - `doom-variable-pitch-font' -- a non-monospace font (where applicable)
;; - `doom-big-font' -- used for `doom-big-font-mode'; use this for
;;   presentations or streaming.
;; - `doom-symbol-font' -- for symbols
;; - `doom-serif-font' -- for the `fixed-pitch-serif' face
;;
;; See 'C-h v doom-font' for documentation and more examples of what they
;; accept. For example:
;;
;;(setq doom-font (font-spec :family "Fira Code" :size 12 :weight 'semi-light)
;;      doom-variable-pitch-font (font-spec :family "Fira Sans" :size 13))
;;
;; If you or Emacs can't find your font, use 'M-x describe-font' to look them
;; up, `M-x eval-region' to execute elisp code, and 'M-x doom/reload-font' to
;; refresh your font settings. If Emacs still can't find your font, it likely
;; wasn't installed correctly. Font issues are rarely Doom issues!

;; There are two ways to load a theme. Both assume the theme is installed and
;; available. You can either set `doom-theme' or manually load a theme with the
;; `load-theme' function. This is the default:
(setq doom-theme 'doom-one)
;; Specify both a dark and light theme, like so and Doom will choose which one
;; to load based on your system light/dark setting:
;;
;;   (setq doom-theme '(doom-one   . doom-one-light))   ; (DARK . LIGHT)
;;
;; If you want more pro-active theme switching based on OS light/dark mode, look
;; up the `auto-dark' package.

;; This determines the style of line numbers in effect. If set to `nil', line
;; numbers are disabled. For relative line numbers, set this to `relative'.
(setq display-line-numbers-type 'relative)

;; Reopen GUI frames where the last one was closed, at the same size (or
;; maximized/fullscreen if it was). Works for a normal `emacs' launch and for
;; frames opened with `emacsclient -c' on the daemon. Saved to Doom's cache dir
;; whenever a frame closes and when Emacs quits.
(defvar my/frame-geometry-file (concat doom-cache-dir "frame-geometry.el"))

(defun my/frame-geometry-frame-p (frame)
  "Non-nil if FRAME is a GUI frame whose geometry should be saved/restored.
Skips transient frames such as Doom's org-capture popup."
  (and (frame-live-p frame)
       (display-graphic-p frame)
       (not (frame-parameter frame 'transient))))

(defun my/save-frame-geometry (&optional frame)
  "Write FRAME's position, size and fullscreen state.
FRAME defaults to the selected frame, or any other GUI frame if that one
isn't (under the daemon the selected frame at quit can be the hidden one)."
  (when-let* ((frame (seq-find #'my/frame-geometry-frame-p
                               (cons (or frame (selected-frame))
                                     (unless frame (frame-list))))))
    (with-temp-file my/frame-geometry-file
      (prin1 (list :position (frame-position frame)
                   :width (frame-text-width frame)
                   :height (frame-text-height frame)
                   :fullscreen (frame-parameter frame 'fullscreen))
             (current-buffer)))))

(defvar my/frame-min-size '(120 . 35)
  "Smallest size, in columns and lines, a restored frame opens at.")

(defun my/restore-frame-geometry (&optional frame)
  "Apply the geometry saved by `my/save-frame-geometry' to FRAME, if any.
FRAME defaults to the selected frame. Either way, FRAME opens at least
`my/frame-min-size'."
  (let ((frame (or frame (selected-frame))))
    (when (my/frame-geometry-frame-p frame)
      (let* ((geometry (when (file-readable-p my/frame-geometry-file)
                         (with-temp-buffer
                           (insert-file-contents my/frame-geometry-file)
                           (read (current-buffer)))))
             (position (plist-get geometry :position))
             (fullscreen (plist-get geometry :fullscreen)))
        ;; Pixel sizes; compare against the minimum before resizing, since
        ;; the frame's reported size can lag behind `set-frame-size'.
        (set-frame-size
         frame
         (max (or (plist-get geometry :width) (frame-text-width frame))
              (* (car my/frame-min-size) (frame-char-width frame)))
         (max (or (plist-get geometry :height) (frame-text-height frame))
              (* (cdr my/frame-min-size) (frame-char-height frame)))
         t)
        (when position
          (set-frame-position frame (car position) (cdr position)))
        (when fullscreen
          (set-frame-parameter frame 'fullscreen fullscreen))))))

;; Save: when Emacs quits, and when any frame closes (with the daemon, closing
;; a frame is how you "quit").
(add-hook 'kill-emacs-hook #'my/save-frame-geometry)
(add-hook 'delete-frame-functions #'my/save-frame-geometry)
;; Restore: the first frame of a normal launch, and every emacsclient frame.
(add-hook 'window-setup-hook #'my/restore-frame-geometry)
(add-hook 'server-after-make-frame-hook #'my/restore-frame-geometry)

;; If you use `org' and don't want your org files in the default location below,
;; change `org-directory'. It must be set before org loads!
(setq org-directory "~/org/")

;; Every .org file in `org-directory' (todo.org, birthdays.org, ...) feeds the
;; agenda, so new files show up without being registered here.
(setq org-agenda-files (list org-directory))

(defun my/org-capture-birthday-template ()
  "Ask for a name and date, return a birthday entry that shows the age in the agenda."
  (let* ((name (read-string "Name: "))
         (date (decode-time
                (org-read-date nil t nil (format "%s's birthday: " name)))))
    ;; `%\\%(' stops capture from running the sexp; it's saved as `%%('.
    (format "* %s's Birthday\n%%\\%%(org-anniversary %d %d %d) %s's %%d%%s birthday\n%%?"
            name
            (decoded-time-year date) (decoded-time-month date) (decoded-time-day date)
            name)))

(after! org
  ;; SPC X <key>. Replaces Doom's defaults so captured items look like the
  ;; rest of todo.org (TODO headings, not [ ] checkboxes).
  (setq org-capture-templates
        '(;; Quick task into Inbox; refile it later with SPC m r r
          ("t" "Task" entry
           (file+headline "todo.org" "Inbox")
           "* TODO %?\n:PROPERTIES:\n:CREATED: %U\n:END:"
           :empty-lines 1)
          ;; Same, plus a link back to the file/heading you were in
          ("T" "Task with link" entry
           (file+headline "todo.org" "Inbox")
           "* TODO %?\n:PROPERTIES:\n:CREATED: %U\n:END:\n%a"
           :empty-lines 1)
          ;; Scheduled work task, filed directly
          ("w" "Work task" entry
           (file+olp "todo.org" "Work" "Tasks")
           "* TODO %?\nSCHEDULED: %^t"
           :empty-lines 1)
          ;; One-off meeting with a date and time
          ("m" "Meeting" entry
           (file+olp "todo.org" "Work" "Meetings")
           "* %?\n%^T"
           :empty-lines 1)
          ;; Trip packing checklist; edit the list in templates/packing.org
          ("p" "Packing list" entry
           (file+olp "todo.org" "Personal" "Tasks")
           (file "templates/packing.org")
           :empty-lines 1)
          ;; Birthday into birthdays.org
          ("b" "Birthday" entry
           (file "birthdays.org")
           (function my/org-capture-birthday-template)
           :empty-lines-before 1)))

  ;; SPC m r r offers only todo.org headings (Inbox, Work/Tasks,
  ;; Personal/Tasks, ...), not birthdays.org.
  (setq org-refile-targets
        `((,(expand-file-name "todo.org" org-directory) :maxlevel . 2))))

;; Entries with a :STYLE: habit property (e.g. feeding the cat) show a
;; consistency graph in the agenda instead of a plain scheduled line.
(after! org-agenda
  (require 'org-habit)
  ;; Show habits on every day of a multi-day agenda, not only today, so a
  ;; habit that isn't due again until tomorrow still appears in the week view.
  (setq org-habit-show-habits-only-for-today nil))

(after! org-agenda
  ;; SPC o A d: one-screen daily review.
  ;; SPC o A e (org-store-agenda-views) also writes it to ~/org/exports/ as
  ;; HTML, Org (full entries) and plain text.
  (setq org-agenda-custom-commands
        `(("d" "Daily review"
           ((agenda "" ((org-agenda-span 'day)
                        ;; Doom starts agendas 3 days back; show today.
                        (org-agenda-start-day nil)))
            (todo "NEXT" ((org-agenda-overriding-header "Next")))
            (todo "WAIT" ((org-agenda-overriding-header "Waiting on")))
            (tags-todo "inbox" ((org-agenda-overriding-header "Inbox to refile"))))
           nil
           (,(expand-file-name "exports/daily-review.html" org-directory)
            ,(expand-file-name "exports/daily-review.org" org-directory)
            ,(expand-file-name "exports/daily-review.txt" org-directory)))))

  ;; Create ~/org/exports on first export instead of failing on a missing dir.
  (defadvice! my/org-make-exports-dir-a (&rest _)
    :before #'org-store-agenda-views
    (make-directory (expand-file-name "exports" org-directory) t)))

(after! org
  ;; Priorities by urgency:
  ;;   A = due this week or blocking someone
  ;;   B = normal (the default; no cookie needed)
  ;;   C = someday / nice to have
  (setq org-priority-highest ?A
        org-priority-lowest ?C
        org-priority-default ?B)

  ;; SPC m q: one-key context tags, alongside the tags already in the file.
  (setq org-tag-alist
        '(("@computer" . ?c) ("@home" . ?h) ("@errand" . ?e) ("@phone" . ?p))))

(after! org
  ;; SPC m A moves a finished subtree to archive/<file>_archive, filed under a
  ;; year/month/day tree, instead of keeping "Completed Tasks" sections.
  (setq org-archive-location "archive/%s_archive::datetree/")

  ;; Record when things close and why they slip, in a folded LOGBOOK drawer.
  ;; Rescheduling prompts for a reason.
  (setq org-log-done 'time
        org-log-into-drawer t
        org-log-reschedule 'note)

  ;; NEXT = doing now, WAIT = blocked on someone/something (asks why),
  ;; CANX = dropped (asks why).
  (setq org-todo-keywords
        '((sequence "TODO(t)" "NEXT(n)" "WAIT(w@/!)" "|" "DONE(d)" "CANX(c@)"))
        org-todo-keyword-faces
        '(("NEXT" . +org-todo-active)
          ("WAIT" . +org-todo-onhold)
          ("CANX" . +org-todo-cancel))))


;; Whenever you reconfigure a package, make sure to wrap your config in an
;; `with-eval-after-load' block, otherwise Doom's defaults may override your
;; settings. E.g.
;;
;;   (with-eval-after-load 'PACKAGE
;;     (setq x y))
;;
;; The exceptions to this rule:
;;
;;   - Setting file/directory variables (like `org-directory')
;;   - Setting variables which explicitly tell you to set them before their
;;     package is loaded (see 'C-h v VARIABLE' to look them up).
;;   - Setting doom variables (which start with 'doom-' or '+').
;;
;; Here are some additional functions/macros that will help you configure Doom.
;;
;; - `load!' for loading external *.el files relative to this one
;; - `add-load-path!' for adding directories to the `load-path', relative to
;;   this file. Emacs searches the `load-path' when you load packages with
;;   `require' or `use-package'.
;; - `map!' for binding new keys
;;
;; To get information about any of these functions/macros, move the cursor over
;; the highlighted symbol at press 'K' (non-evil users must press 'C-c c k').
;; This will open documentation for it, including demos of how they are used.
;; Alternatively, use `C-h o' to look up a symbol (functions, variables, faces,
;; etc).
;;
;; You can also try 'gd' (or 'C-c c d') to jump to their definition and see how
;; they are implemented.
