(in-package :cepl.context)

;; This is an object which can be used to access data about the gl-context
;; it employs caching for any of the areas where the data won't change during
;; the execution or where the changes would be known.

;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

(let ((available-extensions nil))
  (defun has-feature (x)
    (unless available-extensions
      (let* ((exts (if (>= (gl:major-version) 3)
                       (loop :for i :below (gl:get-integer :num-extensions)
                          :collect (%gl:get-string-i :extensions i))
                       ;; OpenGL version < 3
                       (cepl-utils:split-string
			#\space (gl:get-string :extensions))))
             (exts (append exts
                           (mapcar (lambda (x)
                                     (cepl-utils:kwd (string-upcase (subseq x 3))))
                                   exts))))
        (setf available-extensions exts)))
    (not (null (find x available-extensions :test #'equal)))))

(defun ensure-cepl-compatible-setup ()
  (unless (or (> (gl:major-version) 3)
	      (and (= (gl:major-version) 3)
		   (>= (gl:minor-version) 1)))
    (error "Cepl requires OpenGL 3.1 or higher. Found: ~a.~a"
           (gl:major-version) (gl:minor-version))))

(defun %set-default-gl-options ()
  (gl:clear-color 0.0 0.0 0.0 0.0)
  (gl:enable :cull-face)
  (gl:cull-face :back)
  (gl:front-face :ccw)
  (gl:enable :depth-test)
  (gl:depth-mask :true)
  (gl:depth-func :less)
  (gl:depth-range 0.0 1.0)
  (gl:enable :depth-clamp))

;; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

(defmethod clear-gl-context-cache ((object gl-context))
  (clrhash (slot-value object 'cache)))

(defmacro def-cached-context-reader (name &key (enum-name name) index
					    no-defgeneric)
  (let ((kwd-name (kwd enum-name)))
    `(progn
       ,(unless no-defgeneric `(defgeneric ,name (context)))
       (defmethod ,name ((context gl-context))
	 (with-slots (cache) context
	   (or (gethash ,kwd-name cache)
	       (setf (gethash ,kwd-name cache)
		     (gl:get* ,kwd-name ,@(when index (list index))))))))))
(defmacro def-context-reader (name &key (enum-name name) index)
  (let ((kwd-name (kwd enum-name)))
    `(progn
       (defgeneric ,name (context))
       (defmethod ,name ((context gl-context))
         (declare (ignore context))
         (gl:get* ,kwd-name ,@(when index (list index))))
       ;; (define-compiler-macro ,name (&rest args)
       ;;   (declare (ignore args))
       ;;   '(gl:get* ,kwd-name ,@(when index (list index))))
       )))

;;------------------------------------------------------------

(defvar *context-defaults* nil)

(defun set-context-defaults (context)
  (loop :for setting :in *context-defaults* :do
     (apply (symbol-function (first setting)) (cons context (rest setting)))))

;;------------------------------------------------------------

;; GL_CONTEXT_FLAGS (integer)
;; The flags with which the context was created (such as debugging
;; functionality).
(def-cached-context-reader %context-flags :enum-name :context-flags)

;; GL_MAJOR_VERSION (integer)
;; The major version number of the OpenGL API supported by the current
;; context.
(def-cached-context-reader major-version)

;; GL_MINOR_VERSION (integer)
;; The minor version number of the OpenGL API supported by the current context.
(def-cached-context-reader minor-version)

(let ((version 0.0))
  (defun version-float (context)
    (unless (> version 0.0)
      (setf version (+ (major-version context)
                       (/ (minor-version context) 10))))
    (coerce version 'single-float)))

(defun split-float-version (float)
  (let* ((fix (round float .1)))
    (multiple-value-bind (maj min) (floor fix 10)
      (list maj min))))

;; GL_MAX_SERVER_WAIT_TIMEOUT (64-bit integer, at least 0, see glWaitSync)
;; The maximum glWaitSync timeout interval.
(def-cached-context-reader max-server-wait-timeout)

;; GL_MIN_MAP_BUFFER_ALIGNMENT (integer, at least 64)
;; The minimum alignment in basic machine units of pointers returned
;; from glMapBuffer and glMapBufferRange.
(def-cached-context-reader min-map-buffer-alignment)

;; GL_NUM_EXTENSIONS (integer, see glGetString)
;; The number of extensions supported by the GL implementation for the current
;; context.
(def-cached-context-reader extension-count :enum-name :num-extensions)

;; GL_NUM_SHADING_LANGUAGE_VERSIONS (integer, at least 3, see glGetString)
;; The number of supported GLSL versions.
(def-cached-context-reader supported-shading-versions-count
    :enum-name :num-shading-language-versions)

;; GL_TIMESTAMP (GLint64, see glQueryCounter)
;; The 64-bit value of the current GL time.
(def-cached-context-reader timestamp)

;;------------------------------------------------------------

;; GL_ARRAY_BUFFER_BINDING (GLint, initially 0, see glBindBuffer)
;; The name of the buffer object currently bound to the target GL_ARRAY_BUFFER.
;; If no buffer object is bound to this target, 0 is returned.
(def-context-reader %array-buffer-binding :enum-name :array-buffer-binding)

;; GL_COPY_READ_BUFFER_BINDING (name, initially 0, see glBufferBinding)
;; The buffer that is currently bound to the copy read bind point, or 0 for none
(def-context-reader %read-buffer-binding :enum-name :read-buffer-binding)

;; GL_COPY_WRITE_BUFFER_BINDING (name, initially 0, see glBufferBinding)
;; The buffer that is currently bound to the copy write bind point, or 0 for
;; none.
(def-context-reader %copy-write-buffer-binding
    :enum-name :copy-write-buffer-binding)

;; GL_DRAW_INDIRECT_BUFFER_BINDING (GLint, initially 0, see glBindBuffer)
;; The name of the buffer object currently bound to the target
;;  GL_DRAW_INDIRECT_BUFFER. If no buffer object is bound to this target, 0 is
;; returned.
(def-context-reader %draw-indirect-buffer-binding
    :enum-name :draw-indirect-buffer-binding)

;; GL_ELEMENT_ARRAY_BUFFER_BINDING (GLint, initially 0, see glBindBuffer)
;; The name of the buffer object currently bound to the target
;; GL_ELEMENT_ARRAY_BUFFER. If no buffer object is bound to this target, 0 is
;; returned.
(def-context-reader %element-array-buffer-binding
    :enum-name :element-array-buffer-binding)

;; GL_QUERY_BUFFER_BINDING (name, initially 0, see glBufferBinding)
;; The buffer that is currently bound to the query bind point, or 0 for none.
(def-context-reader %query-buffer-binding :enum-name :query-buffer-binding)

;; GL_TEXTURE_BUFFER_BINDING (name, initially 0, see glBufferBinding)
;; The buffer that is currently bound to the generic texture bind point, or 0
;; for none.
(def-context-reader %texture-buffer-binding :enum-name :texture-buffer-binding)

;; GL_VERTEX_ARRAY_BINDING (GLint, initially 0, see glBindVertexArray)
;; The name of the vertex array object currently bound to the context, or 0 if
;; none is bound.
(def-context-reader %vertex-array-binding :enum-name :vertex-array-binding)

;;------------------------------------------------------------


;; GL_COLOR_CLEAR_VALUE (GLfloat[4], initially (0.0, 0.0, 0.0, 0.0), see glClearColor)
;;     The red, green, blue, and alpha values used to clear the color buffers. Integer values, if requested, are linearly mapped from the internal floating-point representation such that 1.0 returns the most positive representable integer value, and -1.0 returns the most negative representable integer value.
(def-context-reader color-clear-value)

;; GL_COLOR_WRITEMASK (singualar or indexed[value of MAX_DRAW_BUFFERS] GLboolean[4], initially (GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE), see glColorMask)
;;     The red, green, blue, and alpha write enables for the color buffers. The single form reads from the first attached color buffer.
(def-context-reader color-writemask)

;; GL_DEPTH_CLEAR_VALUE (GLfloat, initially 1, see glClearDepth)
;;     The value that is used to clear the depth buffer. Integer values, if requested, are linearly mapped from the internal floating-point representation such that 1.0 returns the most positive representable integer value, and -1.0 returns the most negative representable integer value.
(def-context-reader depth-clear-value)


;; GL_DEPTH_FUNC (GLenum, initially GL_LESS, see glDepthFunc)
;;     The depth comparison function.
(def-context-reader depth-func~1)

;; GL_DEPTH_TEST (GLboolean, initially GL_FALSE, see glDepthFunc and glDepthRange)
;;     Whether depth testing of fragments is enabled.
(def-context-reader depth-test)

;; GL_DEPTH_WRITEMASK (GLboolean, initially GL_FALSE, see glDepthMask)
;;     If the depth buffer is enabled for writing.
(def-context-reader depth-writemask)

;; GL_DOUBLEBUFFER (GLboolean)
;;     Whether double buffering is supported.
(def-context-reader doublebuffer)

;; GL_DRAW_BUFFER (GLenum, see glDrawBuffer)
;;     Which buffers are being drawn to. This is selected from the currently bound GL_DRAW_FRAMEBUFFER. See glDrawBuffer. The initial value is GL_BACK if there are back buffers, otherwise it is GL_FRONT.
(def-context-reader draw-buffer)

;; GL_DRAW_FRAMEBUFFER_BINDING (name, initially 0, see glBindFramebuffer)
;;     The framebuffer object currently bound to the GL_DRAW_FRAMEBUFFER target. If the default framebuffer is bound, this value will be zero.
(def-context-reader draw-framebuffer-binding)

;; GL_MAX_COLOR_ATTACHMENTS (integer, at least 8)
;;     Maximum number of framebuffer attachment points for color buffers.
(def-cached-context-reader max-color-attachments)

;; GL_MAX_COLOR_TEXTURE_SAMPLES (integer, at least 1)
;;     The maximum number of samples for all color formats in a multisample texture.
(def-cached-context-reader max-color-texture-samples)

;; GL_MAX_DEPTH_TEXTURE_SAMPLES (integer, at least 1)
;;     The maximum number of samples in a multisample depth or depth-stencil texture.
(def-cached-context-reader max-depth-texture-samples)

;; GL_MAX_DRAW_BUFFERS (integer, at least 8, see glDrawBuffers)
;;     The maximum number of simultaneous outputs that may be written in a fragment shader.
(def-cached-context-reader max-draw-buffers)

;; GL_MAX_DUAL_SOURCE_DRAW_BUFFERS (integer, at least 1, see glBlendFunc and glBlendFuncSeparate)
;;     The maximum number of active draw buffers when using dual-source blending.
(def-cached-context-reader max-dual-source-draw-buffers)

;; GL_MAX_FRAMEBUFFER_HEIGHT (integer, at least 16384, see glFramebufferParameter)
;;     The maximum height for a framebuffer that has no attachments.
(def-cached-context-reader max-framebuffer-height)

;; GL_MAX_FRAMEBUFFER_LAYERS (integer, at least 2048, see glFramebufferParameter)
;;     The maximum number of layers for a framebuffer that has no attachments.
(def-cached-context-reader max-framebuffer-layers)

;; GL_MAX_FRAMEBUFFER_SAMPLES (integer, at least 4, see glFramebufferParameter)
;;     The maximum samples in a framebuffer that has no attachments.
(def-cached-context-reader max-framebuffer-samples)

;; GL_MAX_FRAMEBUFFER_WIDTH (integer, at least 16384, see glFramebufferParameter)
;;     The maximum width for a framebuffer that has no attachments.
(def-cached-context-reader max-framebuffer-width)

;; GL_MAX_INTEGER_SAMPLES (integer, at least 1)
;;     The maximum number of samples supported in integer format multisample buffers.
(def-cached-context-reader max-integer-samples)

;; GL_MAX_SAMPLES (integer, at least 4)
;; The maximum number of samples supported for all non-integer formats.
(def-cached-context-reader max-samples)

;; GL_READ_BUFFER (symbolic constant, initial value below, see glReadPixels
;;     {Which color buffer is selected for reading. The initial value is GL_BACK if there is a back buffer, otherwise it is GL_FRONT. This is selected from the currently bound GL_READ_FRAMEBUFFER.
(def-context-reader read-buffer)

;; GL_READ_FRAMEBUFFER_BINDING (name, intially 0, see glBindFramebuffer)
;;     The framebuffer object currently bound to the GL_READ_FRAMEBUFFER target. If the default framebuffer is bound, this value will be zero.
(def-context-reader read-framebuffer-binding)

;; GL_RENDERBUFFER_BINDING (name, initially 0, see glBindRenderbuffer)
;;     The name of the renderbuffer object currently bound to the target GL_RENDERBUFFER. If no renderbuffer object is bound to this target, 0 is returned.
(def-context-reader renderbuffer-binding)

;; GL_STENCIL_BACK_FAIL (symbolic constant, initially GL_KEEP, see glStencilOpSeparate)
;;     What action is taken for back-facing polygons when the stencil test fails.
(def-context-reader stencil-back-fail)

;; GL_STENCIL_BACK_FUNC (symbolic constant, initially GL_ALWAYS, see glStencilFuncSeparate)
;;     What function is used for back-facing polygons to compare the stencil reference value with the stencil buffer value.
(def-context-reader stencil-back-func)

;; GL_STENCIL_BACK_PASS_DEPTH_FAIL (symbolic constant, initially GL_KEEP, see glStencilOpSeparate)
;;     What action is taken for back-facing polygons when the stencil test passes, but the depth test fails.
(def-context-reader stencil-back-pass-depth-fail)

;; GL_STENCIL_BACK_PASS_DEPTH_PASS (symbolic constant, initially GL_KEEP, see glStencilOpSeparate)
;;     What action is taken for back-facing polygons when the stencil test passes and the depth test passes.
(def-context-reader stencil-back-pass-depth-pass)

;; GL_STENCIL_BACK_REF (integer, initially 0, see glStencilFuncSeparate)
;;     The reference value that is compared with the contents of the stencil buffer for back-facing polygons.
(def-context-reader stencil-back-ref)

;; GL_STENCIL_BACK_VALUE_MASK (integer, initially ~0 (all ones), see glStencilFuncSeparate)
;;     The mask that is used for back-facing polygons to mask both the stencil reference value and the stencil buffer value before they are compared.
(def-context-reader stencil-back-value-mask)

;; GL_STENCIL_BACK_WRITEMASK (integer, initially ~0 (all ones), see glStencilMaskSeparate)
;;     The mask that controls writing of the stencil bitplanes for back-facing polygons.
(def-context-reader stencil-back-writemask)

;; GL_STENCIL_CLEAR_VALUE (integer, initially 0)
;;     The index to which the stencil bitplanes are cleared. See glClearStencil.
(def-context-reader stencil-clear-value)

;; GL_STENCIL_FAIL (symbolic constant, initially GL_KEEP, see glStencilOp)
;;     What action is taken when the stencil test fails. This stencil state only affects non-polygons and front-facing polygons. Back-facing polygons use separate stencil state. See glStencilOpSeparate.
(def-context-reader stencil-fail)

;; GL_STENCIL_FUNC (symbolic constant, initially GL_ALWAYS)
;;     What function is used to compare the stencil reference value with the stencil buffer value. See glStencilFunc. This stencil state only affects non-polygons and front-facing polygons. Back-facing polygons use separate stencil state. See glStencilFuncSeparate and GL_STENCIL_BACK_FUNC.
(def-context-reader stencil-func)

;; GL_STENCIL_PASS_DEPTH_FAIL (symbolic constant, initially GL_KEEP, see glStencilOp)
;;     What action is taken when the stencil test passes, but the depth test fails. This stencil state only affects non-polygons and front-facing polygons. Back-facing polygons use separate stencil state. See glStencilOpSeparate.
(def-context-reader stencil-pass-depth-fail)

;; GL_STENCIL_PASS_DEPTH_PASS (symbolic constant, initially GL_KEEP, see glStencilOp)
;;     What action is taken when the stencil test passes and the depth test passes. This stencil state only affects non-polygons and front-facing polygons. Back-facing polygons use separate stencil state. See glStencilOpSeparate.
(def-context-reader stencil-pass-depth-pass)

;; GL_STENCIL_REF (integer, initially 0, see glStencilFunc)
;;     The reference value that is compared with the contents of the stencil buffer. This stencil state only affects non-polygons and front-facing polygons. Back-facing polygons use separate stencil state. See glStencilFuncSeparate.
(def-context-reader stencil-ref)

;; GL_STENCIL_TEST (boolean, initially GL_FALSE, see glIsEnabled)
;;     Whether stenciling is enabled.
(def-context-reader stencil-test)

;; GL_STENCIL_VALUE_MASK (integer, initially ~0 (all ones), see glStencilFunc)
;;     The mask that is used to mask both the stencil reference value and the stencil buffer value before they are compared. This stencil state only affects non-polygons and front-facing polygons. Back-facing polygons use separate stencil state. See glStencilFuncSeparate.
(def-context-reader stencil-value-mask)

;; GL_STENCIL_WRITEMASK (integer, initially ~0 (all ones), see glStencilMask)
;;     The mask that controls writing of the stencil bitplanes. This stencil state only affects non-polygons and front-facing polygons. Back-facing polygons use separate stencil state. See glStencilMaskSeparate.
(def-context-reader stencil-writemask)

;; GL_STEREO (boolean)
;;     Whether stereo buffers (left and right) are supported.
(def-context-reader stereo)

;;------------------------------------------------------------

;; GL_DRAW_BUFFERi (symbolic constant, see glDrawBuffers)
;;     params returns one value, a symbolic constant indicating which buffers are being drawn to by the corresponding output color. This is selected from the currently bound GL_DRAW_FRAMEBUFFER The initial value of GL_DRAW_BUFFER0 is GL_BACK if there are back buffers, otherwise it is GL_FRONT. The initial values of draw buffers for all other output colors is GL_NONE. i can be from 0 up to the value of MAX_DRAW_BUFFERS minus one.
(defgeneric draw-buffer-i (context buffer-num))

(defmethod draw-buffer-i ((context gl-context) (buffer-num integer))
  (declare (ignore context))
  (cl-opengl:get* (kwd :draw-buffer buffer-num)))
