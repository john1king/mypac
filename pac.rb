require "json"
require "erb"
require "optparse"

class ProxyAutoConfig
  Version = "0.1.0"
  SESSION_RE = /^\s*\[(.+)\]\s*$/
  EMPTY_LINE_RE = /^\s*$/
  TEMPLATE_FILE = File.join(File.dirname(__FILE__), 'proxy.pac.erb')
  DOMAIN_FILE =  File.join(File.dirname(__FILE__), 'domains.txt')

  attr_reader :domains, :proxy

  def self.parse(args)
    options = OpenStruct.new
    options.domain_files = [DOMAIN_FILE]
    options.only_user_file = false
    options.output_file = "proxy.pac"
    options.proxy = "127.0.0.1:1080"

    opt_parser = OptionParser.new do |opts|
      opts.banner = "Usage: pac.rb [options]"

      opts.separator ""
      opts.separator "Specific options:"

      opts.on("-o", "--only", "Only user specified domain file") do |o|
        options.domain_files = []
      end

      opts.on("-f", "--file x,y,z", Array, "Domain file list") do |list|
        options.domain_files.concat list
      end

      opts.on("-p", "--proxy [PROXY]", String, "Proxy server address") do |proxy|
        options.proxy = proxy
      end

      opts.on("-d", "--dest [FILE]", String, "Output file name, default is proxy.pac") do |file|
        options.output_file = file
      end

      opts.separator ""
      opts.separator "Common options:"

      opts.on_tail("-h", "--help", "Show this message") do
        puts opts
        exit
      end

      opts.on_tail("--version", "Show version") do
        puts VERSION
        exit
      end
    end

    opt_parser.parse!(args)
    options
  end

  def self.generate
    options = self.parse(ARGV)
    domains = options.domain_files.reduce({}) do |domain, file|
      self.load_domains(file, domain)
    end
    pac = ProxyAutoConfig.new(domains.values.flatten, options.proxy)
    open(options.output_file, 'w') do |f|
      f.write(pac.render)
    end
  end

  def self.load_domains(file, domains={})
    open(file) do |f|
      session = nil
      f.each_line do |line|
        next if EMPTY_LINE_RE =~ line || line.start_with?('#', ';')
        if SESSION_RE =~ line
          session = $1
          domains[session] ||= []
        else
          raise 'item found before session' unless session
          domains[session].push line.strip
        end
      end
      domains
    end
  end

  def initialize(domains, proxy)
    @domains = Hash[domains.map{|k| [k, 1]}]
    @proxy = proxy
  end

  def render(template = TEMPLATE_FILE)
    ERB.new(File.read(template), nil, '-').result binding
  end
end

if __FILE__ == $0
  ProxyAutoConfig.generate
end
