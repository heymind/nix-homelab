;;; early-init.el --- 早期初始化配置 -*- lexical-binding: t -*-

;;; Commentary:
;; Emacs 27+ 早期启动配置，在 package 和 UI 初始化之前加载

;;; Code:

;; ============= 性能优化 =============
;; 临时提高 GC 阈值，加快启动速度
(setq gc-cons-threshold most-positive-fixnum
      gc-cons-percentage 0.6)

;; 增加读取进程输出的最大值
(setq read-process-output-max (* 1024 1024)) ; 1MB

;; ============= UI 优化 =============
;; 在启动时就禁用这些 UI 元素，避免闪烁
(push '(menu-bar-lines . 0) default-frame-alist)
(push '(tool-bar-lines . 0) default-frame-alist)
(push '(vertical-scroll-bars) default-frame-alist)

;; 禁用启动画面
(setq inhibit-startup-screen t
      inhibit-startup-message t
      inhibit-startup-echo-area-message user-login-name)

;; ============= 包管理 =============
;; 禁用 package.el，使用 straight.el
(setq package-enable-at-startup nil)
(setq straight-use-package-by-default t)

;; ============= 文件名处理 =============
;; 提高文件名处理性能
(setq file-name-handler-alist-original file-name-handler-alist)
(setq file-name-handler-alist nil)

;; 启动后恢复
(add-hook 'emacs-startup-hook
          (lambda ()
            (setq file-name-handler-alist file-name-handler-alist-original)
            (makunbound 'file-name-handler-alist-original)))

;; ============= 启动后恢复 GC =============
(add-hook 'emacs-startup-hook
          (lambda ()
            (setq gc-cons-threshold (* 16 1024 1024)  ; 16MB
                  gc-cons-percentage 0.1)
            ;; 空闲时进行 GC
            (run-with-idle-timer 5 t #'garbage-collect)))

(provide 'early-init)
;;; early-init.el ends here
