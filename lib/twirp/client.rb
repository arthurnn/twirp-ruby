require 'faraday'

module Twirp
    class ProtoClient
        class << self
            # Configure service package name.
            def package(name)
                @package_name = name.to_s
            end

            # Configure service name.
            def service(name)
                @service_name = name.to_s
            end

            # Configure service routing to handle rpc calls.
            def rpc(rpc_method, input_class, output_class, opts)
                raise ArgumentError.new("input_class must be a Protobuf Message class") unless input_class.is_a?(Class) 
                raise ArgumentError.new("output_class must be a Protobuf Message class") unless output_class.is_a?(Class)
                raise ArgumentError.new("opts[:handler_method] is mandatory") unless opts && opts[:handler_method]

                @base_envs ||= {}
                @base_envs[rpc_method.to_s] = {
                    rpc_method: rpc_method.to_sym,
                    input_class: input_class,
                    output_class: output_class,
                    handler_method: opts[:handler_method].to_sym,
                }
            end

            # Get configured package name as String.
            # And empty value means that there's no package.
            def package_name
                @package_name.to_s
            end

            # Service name as String.
            # Defaults to the current class name.
            def service_name
                (@service_name || self.name).to_s
            end

            # Base Twirp environments for each rpc method.
            def base_envs
                @base_envs || {}
            end


            # Package and servicce name, as a unique identifier for the service,
            # for example "example.v3.Haberdasher" (package "example.v3", service "Haberdasher").
            # This can be used as a path prefix to route requests to the service, because a Twirp URL is:
            # "#{BaseURL}/#{ServiceFullName}/#{Method]"
            def service_full_name
                package_name.empty? ? service_name : "#{package_name}.#{service_name}"
            end

        end # class << self

        def initialize(host)
            @host = host
            @conn = Faraday.new(:url => @host)
        end

        def rpc(method_name, input)
            env = self.class.base_envs[method_name.to_s]
            input_class = env[:input_class]

            resp = @conn.post do |req|
                req.url "/#{self.class.service_full_name}/#{method_name.to_s}"
                req.headers['Content-Type'] = 'application/protobuf'
                req.body = input_class.encode(input_class.new(input)) # TODO: if input.is_a? Hash
            end

            if resp.status >= 200 && resp.status < 300 
                return handle_success(env, resp.body)
            else
                return self.handle_error
            end
        end
        private
            def handle_error
                #: TODO: parse body as json and raise twirp error
                raise "twirp internal error"
            end

            def handle_success(env, body)
                input_class = env[:input_class]
                output = input_class.decode(body)
                return output
            end
    end
end
