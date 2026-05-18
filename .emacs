;; ╔══════════════════════════════════════════════════════════════════╗
;; ║         EMACS CONFIG — FINAL v3 (Universal · Termux · Desktop)  ║
;; ║   Byte-Compile · GCMH · Powerline Cache · Aggressive Defer      ║
;; ╚══════════════════════════════════════════════════════════════════╝
;;
;; Struktur:
;;   §1  Early Init   — GC off saat startup
;;   §2  Package      — archives + use-package
;;   §3  Environment  — deteksi Termux / GUI / Desktop
;;   §4  GCMH         — GC magic hack
;;   §5  Byte-Compile — otomatis compile .el → .elc
;;   §6  UI Dasar     — tampilan, scroll, backup
;;   §7  Theme        — wombat + warna custom
;;   §8  Plugins      — which-key, indent-guides, yasnippet, org, flycheck, company
;;   §9  Powerline    — header-line + mode-line dengan cache
;;   §10 Shortcuts    — F2-F12, window navigation
;;   §11 Benchmark    — startup report

;; ════════════════════════════════════════════════════════════════════
;; §1  EARLY INIT — matikan GC sementara agar startup cepat
;; ════════════════════════════════════════════════════════════════════

(setq gc-cons-threshold most-positive-fixnum)
(setq gc-cons-percentage 1.0)

;; ════════════════════════════════════════════════════════════════════
;; §2  PACKAGE MANAGER
;; ════════════════════════════════════════════════════════════════════

(require 'package)
(setq package-archives
      '(("melpa"  . "https://melpa.org/packages/")
        ("gnu"    . "https://elpa.gnu.org/packages/")
        ("nongnu" . "https://elpa.nongnu.org/packages/")))

;; Jangan auto-load packages dua kali
(setq package-enable-at-startup nil)
(package-initialize)

(unless (package-installed-p 'use-package)
  (package-refresh-contents)
  (package-install 'use-package))

(require 'use-package)

;; use-package global defaults
(setq use-package-always-ensure t)      ;; auto-install jika belum ada
(setq use-package-expand-minimally t)   ;; kurangi overhead macro
(setq use-package-verbose nil)          ;; tidak print log ke *Messages*

;; ════════════════════════════════════════════════════════════════════
;; §3  DETEKSI ENVIRONMENT
;; ════════════════════════════════════════════════════════════════════

(defvar my/is-termux
  (or (getenv "TERMUX_VERSION")
      (file-exists-p "/data/data/com.termux"))
  "Non-nil jika berjalan di Android Termux.")

(defvar my/is-gui (display-graphic-p)
  "Non-nil jika berjalan di GUI Emacs (bukan terminal).")

(defvar my/is-desktop
  (and (not my/is-termux)
       (or my/is-gui
           (memq system-type '(gnu/linux darwin windows-nt))))
  "Non-nil jika berjalan di desktop/laptop.")

;; ════════════════════════════════════════════════════════════════════
;; §4  GCMH — Garbage Collector Magic Hack
;;     Strategi: GC OFF saat mengetik, GC agresif saat idle
;; ════════════════════════════════════════════════════════════════════

(use-package gcmh
  :demand t               ;; load SEGERA, bukan deferred
  :config
  ;; Threshold saat aktif mengetik — cukup besar, tidak interrupt
  ;; Termux (RAM terbatas) : 32MB
  ;; Desktop (RAM longgar)  : 128MB
  (setq gcmh-high-cons-threshold
        (if my/is-termux
            (* 32  1024 1024)    ;; 32 MB
          (* 128 1024 1024)))    ;; 128 MB

  ;; Threshold saat idle — kecil agar memory bersih
  (setq gcmh-low-cons-threshold (* 2 1024 1024))   ;; 2 MB

  ;; Delay idle sebelum GC dipanggil
  ;; Termux: 8 detik (lebih responsif, RAM terbatas)
  ;; Desktop: 15 detik (lebih santai)
  (setq gcmh-idle-delay (if my/is-termux 8 15))

  (setq gcmh-verbose nil)   ;; silent — tidak print info GC
  (gcmh-mode 1))

;; ════════════════════════════════════════════════════════════════════
;; §5  BYTE-COMPILATION OTOMATIS
;;     Ganti native-comp yang tidak tersedia di Termux.
;;     .el → .elc: startup 30-60% lebih cepat, tidak butuh libgccjit
;; ════════════════════════════════════════════════════════════════════

;; 5a. Auto byte-compile file .el saat disimpan (jika ada .elc-nya)
(defun my/byte-compile-on-save ()
  "Byte-compile file .el saat disimpan jika .elc sudah ada sebelumnya.
   Jangan compile file baru tanpa .elc — hindari file .elc stale."
  (when (and buffer-file-name
             (string-suffix-p ".el" buffer-file-name)
             (file-exists-p (concat buffer-file-name "c")))  ;; ada .elc lama
    (byte-compile-file buffer-file-name)))

(add-hook 'after-save-hook #'my/byte-compile-on-save)

;; 5b. Byte-compile ~/.emacs sendiri saat disimpan
(defun my/byte-compile-init-on-save ()
  "Khusus: byte-compile ~/.emacs saat disimpan."
  (when (and buffer-file-name
             (string= (expand-file-name buffer-file-name)
                      (expand-file-name "~/.emacs")))
    (byte-compile-file buffer-file-name)
    (message "[NZR] ~/.emacs ter-byte-compile → .emacs.elc")))

(add-hook 'after-save-hook #'my/byte-compile-init-on-save)

;; 5c. Byte-compile saat idle — kompilasi file .el yang belum punya .elc
;;     Jalankan 30 detik setelah startup, tidak ganggu sesi kerja
(defun my/idle-byte-compile-packages ()
  "Byte-compile semua file .el di package dir yang belum ada .elc-nya.
   Dijalankan saat Emacs idle 30 detik setelah startup."
  (let ((dirs (list package-user-dir
                    (expand-file-name "lisp/" user-emacs-directory))))
    (dolist (dir dirs)
      (when (file-directory-p dir)
        (dolist (el-file (directory-files-recursively dir "\\.el$"))
          (let ((elc-file (concat el-file "c")))
            (when (and (not (file-exists-p elc-file))
                       ;; Skip file test / *-pkg.el / *-autoloads.el
                       (not (string-match-p
                             "\\(-pkg\\|-autoloads\\|-test\\)\\.el$"
                             el-file)))
              ;; Compile secara silent — tidak tampilkan buffer *Compile-Log*
              (with-demoted-errors "[NZR byte-compile] %s"
                (byte-compile-file el-file)))))))))

;; Jalankan saat idle 30 detik — tidak ganggu startup
(run-with-idle-timer 30 nil #'my/idle-byte-compile-packages)

;; ════════════════════════════════════════════════════════════════════
;; §6  UI DASAR
;; ════════════════════════════════════════════════════════════════════

;; --- Startup ---
(setq inhibit-startup-screen t)
(setq initial-scratch-message nil)
(setq ring-bell-function 'ignore)

;; --- Cursor & Scroll ---
(setq-default cursor-type 'bar)
(blink-cursor-mode t)
(setq scroll-step 1)
(setq scroll-conservatively 101)    ;; tidak loncat saat scroll
(setq scroll-margin 2)              ;; jaga 2 baris padding saat scroll

;; --- Editor ---
(global-display-line-numbers-mode t)
(global-font-lock-mode t)
(show-paren-mode t)
(electric-indent-mode t)
(global-visual-line-mode t)
(setq-default tab-width 4)
(setq-default indent-tabs-mode nil)
(delete-selection-mode t)           ;; ketik → langsung replace selection
(column-number-mode t)              ;; tampilkan kolom di mode-line

;; --- GUI Elements ---
;; Nonaktifkan elemen yang tidak perlu — hemat resource + cleaner look
(menu-bar-mode -1)
(when my/is-gui
  (tool-bar-mode   -1)
  (scroll-bar-mode -1)
  (tooltip-mode    -1))

;; --- Backup & Auto-save ---
(setq backup-directory-alist `(("." . ,(expand-file-name "backups/" user-emacs-directory))))
(setq backup-by-copying t)       ;; copy, bukan rename (lebih aman di Termux)
(setq version-control t)
(setq kept-new-versions 5)
(setq kept-old-versions 2)
(setq delete-old-versions t)
(make-directory (expand-file-name "backups/" user-emacs-directory) t)

;; Auto-save ke folder khusus (bukan scatter di working dir)
(setq auto-save-file-name-transforms
      `((".*" ,(expand-file-name "auto-save/" user-emacs-directory) t)))
(make-directory (expand-file-name "auto-save/" user-emacs-directory) t)

;; --- Encoding ---
(set-language-environment "UTF-8")
(prefer-coding-system 'utf-8)
(set-default-coding-systems 'utf-8)

;; ════════════════════════════════════════════════════════════════════
;; §7  THEME & WARNA
;; ════════════════════════════════════════════════════════════════════

(set-face-background 'default "#000000")
(set-face-foreground 'default "#e0e0e0")
(load-theme 'wombat t)

;; ════════════════════════════════════════════════════════════════════
;; §8  PLUGINS — semua pakai :defer t kecuali yang wajib di startup
;; ════════════════════════════════════════════════════════════════════

;; ── UNDO/REDO ────────────────────────────────────────────────────
;; :defer t — load saat pertama kali C-z ditekan
(use-package undo-fu
  :defer t
  :bind (("C-z"   . undo-fu-only-undo)
         ("C-S-z" . undo-fu-only-redo)
         ("C-/"   . undo-fu-only-undo)
         ("C-?"   . undo-fu-only-redo)))

;; ── WHICH-KEY ────────────────────────────────────────────────────
;; :defer 1 — load 1 detik setelah startup (tidak block)
(use-package which-key
  :defer 1
  :config
  (which-key-mode t)
  (setq which-key-idle-delay 0.5
        which-key-popup-type 'side-window
        which-key-side-window-location 'bottom
        which-key-side-window-max-height 0.3
        which-key-min-display-lines 5
        which-key-max-display-columns 3)
  (set-face-attribute 'which-key-key-face nil
    :foreground "#00ff00" :weight 'bold :background "#0a1a0a")
  (set-face-attribute 'which-key-command-description-face nil
    :foreground "#e0e0e0" :background "#0a1a0a")
  (set-face-attribute 'which-key-group-description-face nil
    :foreground "#00cc00" :weight 'bold :background "#0a1a0a")
  (set-face-attribute 'which-key-separator-face nil
    :foreground "#008800" :background "#0a1a0a")
  (set-face-attribute 'which-key-local-map-description-face nil
    :foreground "#88ff88" :background "#0a1a0a"))

;; ── HIGHLIGHT INDENT GUIDES — Rainbow per level ───────────────────
;; FIX: Hapus :defer — package HARUS load saat startup agar semua
;; hook terdaftar sebelum buffer manapun dibuka.
;; Bug sebelumnya: :defer 2 + :demand nil = race condition → hook
;; terdaftar SETELAH buffer pertama sudah dibuka → tidak muncul.
(use-package highlight-indent-guides
  :demand t    ;; load SEGERA, bukan deferred
  :config

  ;; Method 'column: paling reliable di terminal Android/Termux.
  ;; 'character bergantung font rendering yang sering gagal di mobile.
  (setq highlight-indent-guides-method     'column
        highlight-indent-guides-responsive  'top
        highlight-indent-guides-delay       0
        ;; FIX KRITIS: WAJIB nil.
        ;; Jika t → Emacs auto-set warna berdasarkan theme (sering
        ;; invisible karena kontras rendah), dan MENGABAIKAN
        ;; highlighter-function custom kita di bawah.
        highlight-indent-guides-auto-enabled nil)

  ;; ── Palet warna per level ──────────────────────────────────────
  ;; Garis biasa (level tidak aktif) — gelap, subtle
  (defvar my/indent-colors
    '("#3d0000"   ;; level 1 — merah tua
      "#3d1a00"   ;; level 2 — coklat
      "#2d2d00"   ;; level 3 — kuning tua
      "#003d00"   ;; level 4 — hijau tua
      "#003d3d"   ;; level 5 — teal tua
      "#00003d"   ;; level 6 — biru tua
      "#1a003d"   ;; level 7 — ungu tua
      "#3d0033")  ;; level 8 — pink tua
    "Warna background garis indentasi biasa per level.")

  ;; Garis aktif (level posisi cursor) — terang, mencolok
  (defvar my/indent-colors-top
    '("#ff3333"   ;; level 1 — merah
      "#ff8800"   ;; level 2 — oranye
      "#ffee00"   ;; level 3 — kuning
      "#00ff44"   ;; level 4 — hijau
      "#00ffee"   ;; level 5 — cyan
      "#4488ff"   ;; level 6 — biru
      "#bb44ff"   ;; level 7 — ungu
      "#ff44cc")  ;; level 8 — pink
    "Warna background garis indentasi aktif per level.")

  ;; ── Custom highlighter: warna berbeda tiap level ───────────────
  (defun my/indent-guide-highlighter (level responsive display)
    "Rainbow highlighter: tiap level indentasi punya warna berbeda."
    (let* ((is-top  (eq responsive 'top))
           (palette (if is-top my/indent-colors-top my/indent-colors))
           (color   (nth (mod (1- level) (length palette)) palette)))
      (list :background color :foreground color)))

  (setq highlight-indent-guides-highlighter-function
        #'my/indent-guide-highlighter)

  ;; ── Hooks: prog-mode = parent universal semua bahasa ───────────
  (add-hook 'prog-mode-hook #'highlight-indent-guides-mode)

  ;; Mode yang TIDAK inherit prog-mode — daftarkan satu per satu
  ;; mhtml-mode adalah root cause paling umum: file .html di Emacs
  ;; modern dibuka sebagai mhtml-mode, bukan html-mode
  (dolist (mode '(mhtml-mode
                  html-mode
                  css-mode
                  scss-mode
                  web-mode
                  yaml-mode
                  json-mode
                  conf-mode
                  sh-mode
                  dockerfile-mode
                  nxml-mode
                  sgml-mode))
    (add-hook (intern (concat (symbol-name mode) "-hook"))
              #'highlight-indent-guides-mode))

  ;; ── Fallback: after-change-major-mode-hook ─────────────────────
  ;; Guard (fboundp ...) WAJIB — hook ini bisa dipanggil kapan saja,
  ;; termasuk sebelum package load selesai di sesi lain.
  ;; Tanpa guard → error "Symbol's function definition is void" yang
  ;; muncul silent dan tidak terdeteksi.
  (defun my/maybe-indent-guides ()
    "Aktifkan indent-guides dengan guard keamanan penuh."
    (when (and (fboundp 'highlight-indent-guides-mode)
               buffer-file-name
               (not (minibufferp))
               (not (string-prefix-p " " (buffer-name)))
               (not (string-prefix-p "*" (buffer-name))))
      (highlight-indent-guides-mode 1)))

  (add-hook 'after-change-major-mode-hook #'my/maybe-indent-guides)

  ;; ── Aktifkan untuk buffer yang sudah terbuka ───────────────────
  ;; Kasus: user reload ~/.emacs saat Emacs sudah berjalan dengan
  ;; file terbuka → tanpa ini, buffer lama tidak mendapat indent guides
  (my/maybe-indent-guides))

;; ── YASNIPPET ────────────────────────────────────────────────────
;; :defer t — load saat mode bahasa aktif
(use-package yasnippet
  :defer t
  :hook ((prog-mode  . yas-minor-mode)
         (html-mode  . yas-minor-mode)
         (mhtml-mode . yas-minor-mode)
         (css-mode   . yas-minor-mode)
         (sh-mode    . yas-minor-mode))
  :config
  (make-directory "~/.emacs.d/snippets" t)
  (setq yas-snippet-dirs '("~/.emacs.d/snippets"))
  (yas-reload-all)
  ;; TAB expand snippet, fallback ke indent biasa
  (define-key yas-minor-mode-map (kbd "TAB")   'yas-expand)
  (define-key yas-minor-mode-map (kbd "<tab>") 'yas-expand))

(use-package yasnippet-snippets
  :defer t
  :after yasnippet)

;; ── ORG-MODE ─────────────────────────────────────────────────────
;; :defer t — load hanya saat buka file .org
(use-package org
  :defer t
  :mode ("\\.org\\'" . org-mode)
  :config
  (setq org-startup-indented t
        org-hide-leading-stars t
        org-ellipsis " ▼"
        org-pretty-entities t
        org-todo-keywords '((sequence "TODO" "IN-PROGRESS" "WAITING" "DONE"))
        org-todo-keyword-faces
        '(("TODO"        . (:foreground "#e94560" :weight bold))
          ("IN-PROGRESS" . (:foreground "#5599ff" :weight bold))
          ("WAITING"     . (:foreground "#cc88ff" :weight bold))
          ("DONE"        . (:foreground "#00ff00" :weight bold))))
  :bind (("C-c a" . org-agenda)
         ("C-c c" . org-capture)))

(use-package org-modern
  :defer t
  :after org
  :hook (org-mode . org-modern-mode)
  :config
  (setq org-modern-star  '("◉" "○" "✸" "✿")
        org-modern-todo  t
        org-modern-table t))

;; ── FLYCHECK ─────────────────────────────────────────────────────
;; :defer t — load saat mode bahasa aktif
(use-package flycheck
  :defer t
  :hook ((prog-mode  . flycheck-mode)
         (sh-mode    . flycheck-mode)
         (html-mode  . flycheck-mode)
         (mhtml-mode . flycheck-mode)
         (css-mode   . flycheck-mode))
  :config
  (setq flycheck-check-syntax-automatically '(mode-enabled save)
        flycheck-display-errors-delay 0.5)
  (set-face-attribute 'flycheck-error nil
    :underline '(:color "#e94560" :style wave))
  (set-face-attribute 'flycheck-warning nil
    :underline '(:color "#ffaa00" :style wave))
  (set-face-attribute 'flycheck-info nil
    :underline '(:color "#5599ff" :style wave)))

;; ── COMPANY (AUTOCOMPLETE) ────────────────────────────────────────
;; :defer t — load saat mode bahasa aktif
(use-package company
  :defer t
  :hook ((prog-mode  . company-mode)
         (sh-mode    . company-mode)
         (html-mode  . company-mode)
         (mhtml-mode . company-mode)
         (css-mode   . company-mode))
  :config
  (setq company-idle-delay 0.2
        company-minimum-prefix-length 1
        company-tooltip-limit 10
        company-tooltip-align-annotations t
        company-show-quick-access t
        company-selection-wrap-around t)
  ;; Navigasi: → konfirmasi, Esc batal
  (define-key company-active-map (kbd "<right>")  'company-complete-selection)
  (define-key company-active-map (kbd "RET")      nil)
  (define-key company-active-map (kbd "<return>") nil)
  (define-key company-active-map (kbd "<escape>") 'company-abort)
  (define-key company-active-map (kbd "<up>")     'company-select-previous)
  (define-key company-active-map (kbd "<down>")   'company-select-next)
  (define-key company-active-map (kbd "TAB")      'company-complete-common)
  (global-company-mode t))

;; company-quickhelp: hanya di GUI (popup tooltip butuh graphics)
(use-package company-quickhelp
  :defer t
  :after company
  :if my/is-gui
  :config
  (company-quickhelp-mode t)
  (setq company-quickhelp-delay 0.5))

;; ════════════════════════════════════════════════════════════════════
;; §9  POWERLINE CUSTOM — Header + Mode-line dengan cache 5 detik
;;     Cache mencegah shell command (df, free, uptime) dipanggil
;;     setiap kali cursor bergerak → nol lag
;; ════════════════════════════════════════════════════════════════════

(defvar my/pl-sep-left  "\ue0b0")
(defvar my/pl-sep-right "\ue0b2")

(defun my/pl-seg (text fg bg &optional next-bg)
  "Segment powerline: TEXT dengan warna FG/BG, separator ke NEXT-BG."
  (when (and text (stringp text) (not (string-empty-p (string-trim text))))
    (concat
     (propertize (concat " " (string-trim text) " ")
                 'face `(:background ,bg :foreground ,fg :weight bold))
     (when next-bg
       (propertize my/pl-sep-left
                   'face `(:foreground ,bg :background ,next-bg))))))

;; ── Cache variabel ────────────────────────────────────────────────
(defvar my/cache-disk   "DISK: ..." "Cache penggunaan disk.")
(defvar my/cache-ram    "RAM: ..."  "Cache penggunaan RAM.")
(defvar my/cache-uptime "..."       "Cache uptime sistem.")
(defvar my/cache-cpu    "CPU: ..."  "Cache jumlah core CPU.")
(defvar my/cache-termux ""          "Cache versi Termux.")

(defun my/update-sys-cache ()
  "Update cache info sistem. Dipanggil timer — tidak dipanggil saat render."
  ;; Disk — path adaptif per OS
  (let ((disk-path (cond (my/is-termux "/data")
                         ((eq system-type 'darwin) "/")
                         (t "/"))))
    (setq my/cache-disk
          (with-temp-buffer
            (when (zerop (call-process "df" nil t nil "-h" disk-path))
              (goto-char (point-min))
              (forward-line 1)
              (when (re-search-forward
                     "\\S-+\\s-+\\S-+\\s-+\\(\\S-+\\)\\s-+\\(\\S-+\\)\\s-+\\([0-9]+%\\)"
                     nil t)
                (format "DISK %s/%s (%s)"
                        (match-string 1)
                        (match-string 2)
                        (match-string 3)))))))
  ;; RAM — universal: Linux & Termux
  (setq my/cache-ram
        (with-temp-buffer
          (when (zerop (call-process "free" nil t nil "-m"))
            (goto-char (point-min))
            (forward-line 1)
            (when (re-search-forward
                   "Mem:\\s-+\\([0-9]+\\)\\s-+\\([0-9]+\\)" nil t)
              (let* ((total (string-to-number (match-string 1)))
                     (used  (string-to-number (match-string 2)))
                     (pct   (if (> total 0) (/ (* used 100) total) 0)))
                (format "RAM %dM/%dM (%d%%)" used total pct))))))
  ;; Fallback RAM untuk macOS (pakai vm_stat)
  (when (and (null my/cache-ram) (eq system-type 'darwin))
    (setq my/cache-ram "RAM N/A (macOS)"))
  ;; Uptime
  (setq my/cache-uptime
        (with-temp-buffer
          (when (zerop (call-process "uptime" nil t nil "-p"))
            (string-trim (buffer-string)))))
  ;; CPU cores
  (setq my/cache-cpu
        (with-temp-buffer
          (when (zerop (call-process "nproc" nil t nil))
            (format "CPU %s core" (string-trim (buffer-string))))))
  ;; Termux version (hanya di Termux)
  (setq my/cache-termux
        (if my/is-termux
            (format "Termux %s" (or (getenv "TERMUX_VERSION") "?"))
          "")))

;; Panggil sekali saat startup
(my/update-sys-cache)
;; Update tiap 5 detik saat idle
(run-with-idle-timer 5 t #'my/update-sys-cache)

;; ── HEADER LINE (atas) ───────────────────────────────────────────
(setq-default header-line-format
  '(:eval
    (let* ((path  (or (buffer-file-name) (concat "[" (buffer-name) "]")))
           (fname (if (buffer-file-name)
                      (abbreviate-file-name path)
                    path))
           (fsize (if (buffer-file-name)
                      (format "%d B" (buffer-size))
                    "N/A"))
           (mod   (if (buffer-modified-p) "● MODIFIED" "✓ SAVED"))
           (lines (format "L:%d" (count-lines (point-min) (point-max)))))
      (concat " "
              (my/pl-seg fname "#e0e0e0" "#1a1a2e" "#16213e")
              (my/pl-seg fsize "#e0e0e0" "#16213e" "#0f3460")
              (my/pl-seg mod   "#ffffff" "#0f3460" "#533483")
              (my/pl-seg lines "#e0e0e0" "#533483" nil)))))

(set-face-attribute 'header-line nil
  :background "#000000" :foreground "#888888"
  :box nil :underline nil :overline nil)

;; ── MODE LINE (bawah) ────────────────────────────────────────────
(setq-default mode-line-format
  '(:eval
    (concat " "
            (my/pl-seg (symbol-name major-mode) "#ffffff" "#e94560" "#0f3460")
            (my/pl-seg my/cache-disk            "#ffffff" "#0f3460" "#533483")
            (my/pl-seg my/cache-ram             "#ffffff" "#533483" "#1a1a2e")
            (my/pl-seg my/cache-cpu             "#e0e0e0" "#1a1a2e" "#16213e")
            (my/pl-seg my/cache-uptime          "#e0e0e0" "#16213e" "#0f3460")
            (when (and my/is-termux
                       (not (string-empty-p my/cache-termux)))
              (my/pl-seg my/cache-termux "#e0e0e0" "#0f3460" nil)))))

(set-face-attribute 'mode-line nil
  :background "#000000" :foreground "#888888" :box nil)
(set-face-attribute 'mode-line-inactive nil
  :background "#111111" :foreground "#555555" :box nil)

;; ════════════════════════════════════════════════════════════════════
;; §10 SHORTCUTS
;; ════════════════════════════════════════════════════════════════════

;; Mouse di terminal
(xterm-mouse-mode t)
(global-set-key [mouse-4] 'scroll-down-line)
(global-set-key [mouse-5] 'scroll-up-line)

;; File & buffer
(global-set-key (kbd "C-s")   'save-buffer)
(global-set-key (kbd "C-f")   'isearch-forward)
(global-set-key (kbd "<f2>")  'find-file)
(global-set-key (kbd "<f3>")  'save-buffer)
(global-set-key (kbd "<f4>")  'kill-this-buffer)
(global-set-key (kbd "<f5>")  'revert-buffer)
(global-set-key (kbd "<f12>")
  (lambda () (interactive) (find-file "~/.emacs")))

;; Window navigation
(global-set-key (kbd "M-<left>")  'windmove-left)
(global-set-key (kbd "M-<right>") 'windmove-right)
(global-set-key (kbd "M-<up>")    'windmove-up)
(global-set-key (kbd "M-<down>")  'windmove-down)

;; Split window — buat panel + langsung pindah ke sana
(global-set-key (kbd "C-x |")
  (lambda () (interactive) (split-window-right) (windmove-right)))
(global-set-key (kbd "C-x -")
  (lambda () (interactive) (split-window-below) (windmove-down)))

;; ════════════════════════════════════════════════════════════════════
;; §11 BENCHMARK — tampilkan ringkasan startup di echo area
;; ════════════════════════════════════════════════════════════════════

(add-hook 'emacs-startup-hook
  (lambda ()
    (message
     "[NZR] %.2fs | GC×%d | %s | Byte-compile: ON | GCMH: ON (%dMB)"
     (float-time (time-subtract after-init-time before-init-time))
     gcs-done
     (cond (my/is-termux  "Termux Android")
           (my/is-desktop  "Desktop")
           (t              "Terminal"))
     (/ (if my/is-termux (* 32 1024 1024) (* 128 1024 1024))
        (* 1024 1024)))))
