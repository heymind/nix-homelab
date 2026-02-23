(use-package
 nano
 :straight (nano :type git :host github :repo "rougier/nano-emacs")
 :config
 (setq nano-font-family-monospaced "JetBrainsMono Nerd Font")
 (require 'nano)
 (setq font-lock-maximum-decoration t)
 (setf (alist-get 'internal-border-width default-frame-alist) 12)

 (defun my/sync-nano-theme-with-system (appearance)
   (let* ((appearance-str (format "%s" appearance))
          (system-dark?
           (string-match-p "dark" (downcase appearance-str)))
          ;; 确保 nano-theme-var 有值，防止未初始化报错
          (nano-dark?
           (string= (bound-and-true-p nano-theme-var) "dark")))
     (unless (eq (and system-dark? t) (and nano-dark? t))
       (nano-toggle-theme))))

 (when (and (eq system-type 'darwin) window-system)

   ;; 修复点：针对 Emacs Mac Port (铁路猫版)
   ;; 原代码用 let lambda 并不稳定，改为定义一个专用的无参辅助函数
   (when (boundp 'mac-effective-appearance-change-hook)
     (defun my/sync-mac-port-appearance ()
       (my/sync-nano-theme-with-system
        (plist-get (mac-application-state) :appearance)))

     (add-hook
      'mac-effective-appearance-change-hook
      #'my/sync-mac-port-appearance)
     (my/sync-mac-port-appearance))

   ;; 针对 Emacs Plus / NS (官方版)
   (when (boundp 'ns-system-appearance-change-functions)
     (add-hook
      'ns-system-appearance-change-functions
      #'my/sync-nano-theme-with-system))))
