module React
  module ServerRendering
    # A bare-bones renderer for React.js + Exec.js
    # - Depends on global ReactDOMServer in the ExecJS context
    # - No Rails dependency
    # - No browser concerns

    # NOTE: During the upgrade to React 16.5.2 / React 16.6,
    # we started getting errors from this function, which appeared after
    # the const staticContent line:
    # #{after_render(component_name, props, prerender_options)}
    # This function depended on a variable called "result" to exist,
    # and it stopped existing. We removed it, and it started working.
    class ExecJSRenderer
      def initialize(options={})
        js_code = options[:code] || raise("Pass `code:` option to instantiate a JS context!")
        @context = ExecJS.compile(GLOBAL_WRAPPER + js_code)
      end

      def render(component_name, props, prerender_options)
        render_function = prerender_options.fetch(:render_function, "renderToString")
        js_code = <<-JS
          (function () {
            #{before_render(component_name, props, prerender_options)}
            const staticContent = StyleSheetServer.renderStatic(function() {
              return ReactDOMServer.#{render_function}(React.createElement(#{component_name}, #{props}));
            });
            return (
             "<style>" + staticContent.css.content + "</style>" + staticContent.html
            );
          })()
        JS
        @context.eval(js_code).html_safe
      rescue ExecJS::ProgramError => err
        raise React::ServerRendering::PrerenderError.new(component_name, props, err)
      end

      # Hooks for inserting JS before/after rendering
      def before_render(component_name, props, prerender_options); ""; end
      def after_render(component_name, props, prerender_options); ""; end

      # Handle Node.js & other ExecJS contexts
      GLOBAL_WRAPPER = <<-JS
        var global = global || this;
        var self = self || this;
        var window = window || this;
      JS

    end
  end
end
