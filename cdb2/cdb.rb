#!/usr/bin/env ruby
# Try: http://localhost:4567/cdb/index.html
# Try: http://chiara:3000/env/sw0001/newshowall.mobilehtml/2
# Try: http://chiara:3000/kunde/norisbank/fixit
# Try: http://chiara:3000/env/sw0001/showall.html

require 'rubygems'
require 'sinatra'
require 'yaml'
require 'yaml/store'
require 'json'
require 'erb'

# local includes
require File.join(File.dirname(__FILE__), "ringbuffer.rb")
require File.join(File.dirname(__FILE__), "rundeckyaml.rb")

# set :public_folder, File.dirname(__FILE__) + '/public'


# DEBUG       = false
DEBUG       = true
LOG_ENTRIES = 100

if "root".eql?ENV['USER']
  BASEDIR     = '/srv/cdb_data'
else
  BASEDIR     = ENV['HOME']+'/srv/cdb_data'
end

BASEDIR = File.dirname(__FILE__) + '/../cdb_data'

set :environment, :development
# ---------------------------------------------------
KCODE = 'u' if RUBY_VERSION < '1.9'
before do
  content_type :html, 'charset' => 'utf-8'
end

helpers do
  include Rack::Utils
  alias_method :h, :escape_html
end

if jruby = RUBY_PLATFORM =~ /\bjava\b/
  require 'java'
  java_import java.lang.System
  include_class 'java.lang.StringIndexOutOfBoundsException'
  #BASEDIR = File.join(System.getProperties["user.home"], 'etc', 'cdb')
  CONTEXT = '/cdb'
else
  #BASEDIR = File.join(File.dirname(__FILE__), 'etc', 'cdb')
  CONTEXT = ''
  class StringIndexOutOfBoundsException < StandardError  
  end  
end

print "Hello "+BASEDIR


@@rb = RingBuffer.new LOG_ENTRIES
@@ry = RundeckYaml.new

# --- getter ---
get '/revision' do
  get_revision.to_s
end

get '/freeze' do
  revision = freeze_db
  revision
end

get '/log' do
  get_log
end

get '/:env/showall*' do
  parameter = [ params[:env] ]
  showall(parameter, :out => params[:splat][0])
end

get '/:env/:module/showall*' do
  parameter = [ params[:env], params[:module] ]
  showall(parameter, :out => params[:splat][0])
end

# New
get '/:classs/:objectt/newshowall:format/?:depth?' do
  # write_log "Error: no data in revision found!"
  # write_log "Format = #{params[:format]}"
  # write_log "Depth = #{params[:depth]}"
  parameter = [ params[:classs]+'/'+params[:objectt] ]
  newshowall(parameter, :out => params[:format], :depth =>  params[:depth])
end

get '/:classs/:objectt/fixit' do
  fix_refs( params[:classs]+'/'+params[:objectt] )
end

get '/:env/:module/:app/showall*' do
  parameter = [ params[:env], params[:module], params[:app] ]
  showall(parameter, :out => params[:splat][0])
end

get '/:env/:module/:app/freeze' do
  parameter     = [ params[:env], params[:module], params[:app] ]
  begin
    config        = read_data(parameter)
  rescue Excpetion => e
    return '@@ERROR@@'
  end
  revision      = freeze_app(config, parameter)
  revision
end

get '/:env/:module/:app/:key.filename' do
  parameter     = [ params[:env], params[:module], params[:app] ]
  relevant_file = get_relevantfile(parameter, params[:key])

  relevant_file
end

get '/:revision/:env/:module/:app/:key.json' do
  parameter = [ params[:env], params[:module], params[:app] ]
  revision  = params[:revision]
  config    = {}

  if not revision =~ /[0-9]+$/
    write_log "Error: revision is not a number"
    return "@@ERROR@@" + "Error: revision is not a number"
  else
    write_log "Using revision #{revision.to_s}"
    if revision.to_i < 1
      write_log "Error: please use a valid revision number > 0"
      return "@@ERROR@@" + "Error: please use a valid revision number > 0"
    end

    config = get_revision_data(revision, parameter)
    if config.nil?
      write_log "Error: no data in revision found!"
      return "@@ERROR@@" + "Error: no data in revision found!"
    end
  end
  result          = config[params[:key]]
  formated_result = result.to_json

  if result.nil? or formated_result == "null"
    write_log "Error: Key '#{params[:key]}' not found"
    return "@@ERROR@@" + "Error: Key '#{params[:key]}' not found"
  else
    formated_result
  end
end

get '/disabled/:revision/:env/:module/:app/:key' do
  parameter = [ params[:env], params[:module], params[:app] ]
  revision  = params[:revision]
  config    = {}

  if not revision =~ /[0-9]+$/
    write_log "Error: revision is not a number"
    return "@@ERROR@@" + "Error: revision is not a number"
  else
    write_log "Using revision #{revision.to_s}"
    if revision.to_i < 1
      write_log "Error: please use a valid revision number > 0"
      return "@@ERROR@@" + "Error: please use a valid revision number > 0"
    end

    config = get_revision_data(revision, parameter)
    if config.nil?
      write_log "Error: no data in revision found!"
      return "@@ERROR@@" + "Error: no data in revision found!"
    end
  end
  result          = config[params[:key]]
  formated_result = result.to_s

  if result.nil? or formated_result.empty?
    write_log "Error: Key '#{params[:key]}' not found"
    return "@@ERROR@@" + "Error: Key '#{params[:key]}' not found"
  else
    formated_result
  end
end

get '/:env/:module/:app/:key.json' do
  parameter = [ params[:env], params[:module], params[:app] ]
  revision  = get_revision
  config    = {}

  if revision.to_i == 0
    config = read_data(parameter)
  else
    write_log "Using revision #{revision}"
    config = get_revision_data(revision, parameter)
    if config.nil?
      return "@@ERROR@@" + "Error: no data in revision found!"
    end
  end
  result          = config[params[:key]]
  formated_result = result.to_json

  if result.nil? or formated_result == "null"
    write_log "Error: Key '#{params[:key]}' not found"
    return "@@ERROR@@" + "Error: Key '#{params[:key]}' not found"
  else
    formated_result
  end
end

get '/disabled/:env/:module/:app/:key' do
  parameter = [ params[:env], params[:module], params[:app] ]
  revision  = get_revision
  config    = {}

  if revision.to_i == 0
    begin
      config = read_data(parameter)
    rescue Exception => e
      return '@@ERRRO@@'
    end
  else
    write_log "Using revision #{revision}"
    config = get_revision_data(revision, parameter)
    if config.nil?
      write_log "Error: no data in revision found!"
      return "@@ERROR@@" + "Error: no data in revision found!"
    end
  end
  result          = config[params[:key]]
  formated_result = result.to_s

  if result.nil? or formated_result.empty?
    write_log "Error: Key '#{params[:key]}' not found"
    return "@@ERROR@@" + "Error: Key '#{params[:key]}' not found"
  else
    formated_result
  end
end

# get '/*' do
#   write_log "Error: Request doesn't match a valid route!"
#   return "@@ERROR@@" + "Error: Request doesn't match a valid route!"
# end

# --- setter ---
# please use this only for legacy apps which can not modify the url
# this feauture will GLOBALY change the revision! -- Attention --
post '/revision' do
  begin
    parameter = JSON.parse(params[:json])
    set_revision(parameter["revision"])
  rescue Exception => e
    write_log "Error: while setting revision" 
    write_log e.message
  end
end

post '/:env' do
  parameter     = [ params[:env] ]
  redirect_url  = params[:redirect]

  set_key_in_yaml(parameter, params[:key], params[:json])

  if not redirect_url.nil?
    write_log "Redirect to #{redirect_url}"
    redirect CONTEXT + redirect_url, 302
  end
end

post '/:env/:module' do
  parameter     = [ params[:env], params[:module] ]
  redirect_url  = params[:redirect]

  set_key_in_yaml(parameter, params[:key], params[:json])

  if not redirect_url.nil?
    write_log "Redirect to #{redirect_url}"
    redirect CONTEXT + redirect_url, 302
  end
end

post '/:env/:module/:app' do
  parameter     = [ params[:env], params[:module], params[:app] ]
  redirect_url  = params[:redirect]

  set_key_in_yaml(parameter, params[:key], params[:json])

  if not redirect_url.nil?
    write_log "Redirect to #{redirect_url}"
    redirect CONTEXT + redirect_url, 302
  end
end

# --- create ---
# curl -X PUT http://localhost:4567/UAT/dbde/newapp

put '/:env' do
  parameter     = [ params[:env] ]
  create_empty_yaml(parameter, :create_dir => true)
end

put '/:env/:module' do
  parameter     = [ params[:env], params[:module] ]
  create_empty_yaml(parameter, :create_dir => true)
end

put '/:env/:module/:app' do
  parameter     = [ params[:env], params[:module], params[:app] ]
  create_empty_yaml(parameter)
end

# --- delete ---
# curl -X DELETE http://localhost:4567/UAT/dbde/dboverallsearch/port

delete '/:env/:key' do
  parameter     = [ params[:env], params[:module], params[:app] ]
  delete_key_in_yaml(parameter, params[:key])
end

delete '/:env/:module/:key' do
  parameter     = [ params[:env], params[:module], params[:app] ]
  delete_key_in_yaml(parameter, params[:key])
end

delete '/:env/:module/:app/:key' do
  parameter     = [ params[:env], params[:module], params[:app] ]
  delete_key_in_yaml(parameter, params[:key])
end

# --- private functions ---
private

def fix_refs(nnode)
  # write_log "Fixing #{parameter[0]}"
  # Suche nach "uses"
  changed_config = newread_data([ nnode ])
  # write_log "changed #{changed_config}"
  # Suche "uses"
  uses = uses_list(changed_config)
  uses.each do |used|
    write_log "using #{used}"
    used_list = [ used ]
    target_object = newread_data(used_list)
    write_log "Patching #{target_object}"
    uses_field = target_object["used_by"]
    write_log "Used_by #{uses_field}"
    target_object["used_by"] << nnode
    # Quickly check if sources exist
    # Maybe we should check if the ref i still valid
    list_to_check = target_object["used_by"].uniq
    target_object["used_by"] = []
    list_to_check.each do |file_ref|
      filename = File.join( BASEDIR , file_ref ) + '.yaml'
      if File.exist? filename
        target_object["used_by"] << file_ref
      end
    end
    write_log "Patched #{target_object}"
    write_yaml(used, target_object)
  end
end

def write_yaml(name, data)
  begin
    store = YAML::Store.new( filename_of_object(name), :Indent => 2)
    write_log "Updating: #{filename_of_object(name)}"
    store.transaction do
      data.each_pair do |key, value|
        if store.nil?
          write_log "Error: no valid yaml #{filename_of_object(name)}"
        else
          store[key] = value
        end
      end
    end
    true
  rescue Exception => e
    write_log "Error: while writing back yaml file #{relevant_file}"
    write_log e.message
    false
  end
end

def filename_of_object(name)
  File.join( BASEDIR, name ) + '.yaml'
end


def newshowall(parameter, opts = {})
  begin
    config      = newread_data(parameter, :depth => opts[:depth])
    last_config = newread_data(parameter, :depth => opts[:depth], :disable_merge => true)
  rescue Exception => e
    return '@@ERROR@@: '+e.to_s + e.backtrace.join("\n")
  end

  result = ''

  if opts[:out] == ".html"
    @fields      = config
    @last_fields = last_config
    @depth       = parameter.length
    @context     = CONTEXT
    begin
      erb :fields
    rescue Exception => e
      write_log "Error: in Template processing fields.erb"
      write_log e.message
    end
  elsif  opts[:out] == ".json"
    config.to_json
  elsif  opts[:out] == ".yaml"
    [ 200,  {'Content-Type' => 'text/yaml'} , config.to_yaml]
  elsif  opts[:out] == ".xml"
    "Ausgabe von config.to_xml"
    [ 200,  {'Content-Type' => 'text/xml'} , config.to_xml]
  elsif  opts[:out] == ".rundeckyaml"
    "Ausgabe im rundeck Format"
    [ 200,  {'Content-Type' => 'text/yaml'} , @@ry.to_rundeckyaml(config) ]
  elsif  opts[:out] == ".mobilehtml"
    [ 200,  {'Content-Type' => 'text/html'} , "<h3>#{parameter} Maxtiefe: #{opts[:depth]}</h3><pre>"+to_mhtml(config,0,opts[:depth])+"</pre>" ]
  else
    config.each { |key,value|
      result << key.to_s + ";" + value.to_s + "\n"
    }
    result
  end
end


def showall(parameter, opts = {})
  begin
    config      = newread_data(parameter)
    last_config = newread_data(parameter, :disable_merge => true)
  rescue Exception => e
    return '@@ERROR@@: '+e.to_s + e.backtrace.join("\n")
  end

  result = ''

  if opts[:out] == ".html"
    @fields      = config
    @last_fields = last_config
    @depth       = parameter.length
    @context     = CONTEXT
    begin
      erb :fields
    rescue Exception => e
      write_log "Error: in Template processing fields.erb"
      write_log e.message
    end
  elsif  opts[:out] == ".json"
    config.to_json
  elsif  opts[:out] == ".yaml"
    [ 200,  {'Content-Type' => 'text/yaml'} , config.to_yaml]
  elsif  opts[:out] == ".xml"
    "Ausgabe von config.to_xml"
    [ 200,  {'Content-Type' => 'text/xml'} , config.to_xml]
  elsif  opts[:out] == ".rundeckyaml"
    "Ausgabe im rundeck Format"
    [ 200,  {'Content-Type' => 'text/yaml'} , @@ry.to_rundeckyaml(config) ]
  else
    config.each { |key,value|
      result << key.to_s + ";" + value.to_s + "\n"
    }
    result
  end
end

def newread_data(nnode, options={})
  config    = Hash.new

  filename = filename_of_object(nnode)
  # write_log "Reading: #{File.expand_path(filename)}" if DEBUG
  additional_config = load_yaml(filename)
  depth = 0
  if options[:depth]
    depth = options[:depth].to_i
  end
  list_all_keys(additional_config,depth)
  if additional_config.is_a?(Hash)
    if options[:disable_merge]
      config = additional_config
    else
      config.merge!( additional_config )
    end
  end
  config
end

def uses_list(mytree)
  result = Array.new
  return result unless mytree.is_a? Hash
  mytree.keys.each do |thiskey|
    if thiskey == "uses"
      uses_list = mytree[thiskey]
      uses_list.each do |list_entry|
        result << list_entry
      end
    end
    if mytree[thiskey].is_a? Hash
      result << uses_list(mytree[thiskey])
    end
  end
  result.flatten
end

def list_all_keys(mytree, maxdepth)
  basedir   = BASEDIR
  filename  = ''

  return unless mytree.is_a? Hash
  mytree.keys.each do |thiskey|
    # write_log "Found #{thiskey}" if DEBUG
    if thiskey == "uses" 
      if maxdepth > 0
        maxdepth = maxdepth - 1
        # write_log "maxdepth = #{maxdepth}"
        uses_list = mytree[thiskey]
        uses_list.each do |list_entry|
          basedir = File.join( BASEDIR, list_entry )
          filename = basedir + '.yaml'
          if ! File.exists? filename
            write_log "ERROR: File is missing at #{filename}"
          else
            # write_log "Reading: #{File.expand_path(filename)}" if DEBUG
            additional_config = load_yaml(filename)
            # write_log "Gefunden: #{additional_config}"
            list_all_keys(additional_config,maxdepth)
            mytree[list_entry]=additional_config
          end
        end
      end
    end
    list_all_keys(mytree[thiskey], maxdepth)
    # write_log "EXITING with #{mytree}" if DEBUG
  end
end

def read_data(parameter, options={})
  config    = Hash.new
  basedir   = BASEDIR
  filename  = ''

  parameter.each do |path|
    basedir = File.join( basedir, path.to_s )
    filename = basedir + '.yaml'
    # write_log "Reading: #{File.expand_path(filename)}" if DEBUG
    additional_config = load_yaml(filename)
    if additional_config.is_a?(Hash)
      if options[:disable_merge]
        config = additional_config
      else
        config.merge!( additional_config )
      end
    end
  end
  config
end

def get_revision
  basedir   = BASEDIR
  revision  = 0

  if File.readable?( File.join( basedir, 'repo', 'repo.yaml' ) )
    repo_config = load_yaml( File.join( basedir, 'repo', 'repo.yaml' ) )
    revision = repo_config["use_revision"]
  end
  revision
end

def set_revision(revision)
  basedir = File.join( BASEDIR, 'repo')

  begin
    store = YAML::Store.new( File.join(basedir , 'repo.yaml' ), :Indent => 2)
    store.transaction do
      store["use_revision"] = revision
      if revision == "0"
        write_log "Setting revision to HEAD"
      else
        write_log "Fixating revision to " + revision
      end
    end
  rescue Exception => e
    write_log "Error: while writing repo.yaml"
    write_log e.message
  end
end

def get_revision_data(revision, parameter)
  basedir       = File.expand_path(File.join(BASEDIR, 'repo'))
  revision_link = ''

  revision_link = File.join(basedir, revision.to_s)
  repo_file = get_revision_filename(basedir, revision, parameter)

  if File.file? revision_link
    if not File.file? repo_file
      write_log "Error: there is no matching repository, looking for #{repo_file}"
      return
    end
    load_yaml(revision_link)
  else
    #revision is a full dump directory
    repo_parameter = [ 'repo', revision ]
    repo_parameter = repo_parameter + parameter
    begin
      read_data(repo_parameter)
    rescue Exception => e
      return nil
    end
  end
end

def freeze_db
  basedir       = File.expand_path(File.join(BASEDIR, 'repo'))
  new_revision  = 1

  init_repository(basedir)
  # read repository config
  repo_config = load_yaml( File.join( basedir, 'repo.yaml' ) )
  new_revision = repo_config["next_revision"]

  write_log "Freezing Database to revision " + new_revision.to_s
  revision_dir = File.join(basedir, 'dump' + new_revision.to_s)
  begin
    FileUtils.mkdir(revision_dir)
    Dir.new(BASEDIR).each {|d|
      if not (d == '.' or d == '..' or d == 'repo')
        FileUtils.cp_r(File.expand_path(File.join(BASEDIR, d)), revision_dir)
      end
    }
    File.symlink(File.join(basedir, 'dump' + new_revision.to_s), \
               File.join(basedir, new_revision.to_s))
  rescue Exception => e
    write_log "Error: while freezing Database"
    write_log e.message
  end
  
  increase_revision(basedir)
  new_revision.to_s
end
    
def freeze_app(config, parameter)
  basedir       = File.expand_path(File.join(BASEDIR, 'repo'))
  new_revision  = 1

  init_repository(basedir)
  # read repository config
  repo_config = load_yaml( File.join( basedir, 'repo.yaml' ) )
  new_revision = repo_config["next_revision"]

  write_log "Freezing application " + parameter.last + " to revision " + new_revision.to_s
  begin
    repo_file = get_revision_filename(basedir, new_revision, parameter)
    write_log "Using " + repo_file if DEBUG

    File.open(repo_file, 'w') { |f|
      f.write config.to_yaml
    }
    File.symlink(repo_file, File.join(basedir, new_revision.to_s))
  rescue Exception => e
    write_log "Error: while freezing databse"
    write_log e.message
  end

  increase_revision(basedir)
  new_revision.to_s
end

def init_repository(basedir)
  # init repository if we can not find the directory
  if not File.directory?(basedir)
    write_log "Create repository directory: " + basedir
    FileUtils.mkdir_p(basedir)
  end

  # if there is no repository config, we create one
  if not File.readable?( File.join( basedir, 'repo.yaml' ) )
    initial_repo_config = { "revision"      => 0, \
                            "next_revision" => 1, \
                            "use_revision"  => 0 }
    File.open(File.join( basedir, 'repo.yaml' ), 'w') { |f|
      f.write initial_repo_config.to_yaml
    }
  end
end

def increase_revision(basedir)
    store = YAML::Store.new( File.join( basedir, 'repo.yaml' ), :Indent => 2)
      store.transaction do
        store["revision"]      = store["next_revision"]
        store["next_revision"] = store["next_revision"] + 1
    end
end

def get_revision_filename(basedir, revision, parameter)
    repo_path = basedir
    filename  = ''
    parameter.each do |path|
      filename = filename + path + '_'
    end
    filename = filename + "#{revision.to_s}.yaml"
    repo_path = File.join(repo_path, filename)
    repo_path
end

def get_relevantfile(parameter, key)
  config        = Hash.new
  basedir       = BASEDIR
  filename      = ''
  relevant_file = ''

  parameter.each do |path|
    basedir = File.join( basedir, path.to_s )
    filename = basedir + '.yaml'
    write_log "Reading: #{File.expand_path(filename)}" if DEBUG
    config = load_yaml(filename)
    if not config.nil? and config.has_key?(key)
      relevant_file = File.expand_path(filename)
    end
  end
  relevant_file
end

def load_yaml(filename)
  if File.file? filename
      begin
        YAML::load_file(filename)
      rescue StringIndexOutOfBoundsException => e
        puts "Error: YAML parsing in #{filename}"
        write_log "Error: YAML parsing in #{filename}"
        write_log e.message
        raise "YAML not parsable"
        false
      rescue Exception => e
        puts "Error: YAML parsing in #{filename}"
        write_log "Error: YAML parsing in #{filename}"
        write_log e.message
        raise "YAML not parsable"
        false
      end
  else
    raise "File not found: #{filename}"
  end
end

def create_empty_yaml(parameter, options={})
  relevant_path = BASEDIR
  create_dir    = options[:create_dir]

  parameter.each {|f|
    relevant_path = File.join(relevant_path, f.to_s)
  }
  relevant_file = relevant_path + '.yaml'

  begin
    File.open(relevant_file, 'w') { |f|
      f.write "--- {}\n"
    }
    if create_dir
      FileUtils.mkdir_p relevant_path
    end
    write_log "Created #{parameter.last} in #{params[:env]}"
  rescue Exception => e
    write_log "Error: can not create new entry"
    write_log e.message
  end
end

def set_key_in_yaml(uri_split, key, json)
  data          = ''
  relevant_file = BASEDIR
  
  uri_split.each {|f|
    relevant_file = File.join(relevant_file, f.to_s)
  }
  relevant_file = relevant_file + '.yaml'

  begin
    data = JSON.parse(json)
  rescue Exception => e
    write_log "Error: in parsing data from POST, got: #{data.to_s}"
    write_log e.message
    return
  end

  begin
    store = YAML::Store.new( relevant_file, :Indent => 2)
    write_log "Updating: #{File.expand_path(relevant_file)}"
    store.transaction do
      data.each_pair do |key, value|
        if store.nil?
          write_log "Error: no valid yaml #{File.expand_path(relevant_file)}"
        else
          store[key] = value
        end
      end
    end
    true
  rescue Exception => e
    write_log "Error: while writing back yaml file #{relevant_file}"
    write_log e.message
    false
  end
end

def delete_key_in_yaml(uri_split, key)
  relevant_file = get_relevantfile(uri_split, key)

  begin
    store = YAML::Store.new( relevant_file, :Indent => 2)
    write_log "Deleting #{key} from #{uri_split.last} in #{uri_split.first}"
    store.transaction do
      if store.nil?
          write_log "Error: no valid yaml #{File.expand_path(relevant_file)}"
      else
        store.delete(key)
      end
    end
  rescue Exception => e
    write_log "Error: while deleting key #{key} from #{relevant_file}"
    write_log e.message
  end
end

def write_log(message)
  @@rb.push Time.now.localtime.to_s + ': ' + message
  puts  message
end

def get_log
  log = ''
  @@rb.each do |message|
    log = log + message.to_s + "\n" if not message.nil?
  end
  log
end

def to_mhtml(mytree, the_depth, max_depth) 
	result = ''
  the_new_line = ''
  sub_html = ''

  the_depth = the_depth + 1

  # write_log "mytree.is_a " + mytree.class.to_s

  # return unless mytree.is_a? Hash
  if mytree.is_a? Hash
    mytree.keys.each do |thiskey|
      # write_log "At #{the_depth} found #{thiskey}" if DEBUG
      result = result + indent(the_depth) + thiskey 
      if thiskey == "uses" or thiskey == "used_by"
        result = result + ": "
        uses_list = mytree[thiskey]
        uses_list.each_index do |i|
          if uses_list[i].is_a? String
            classs_name = uses_list[i].split('/')[0]
            objectt_name = uses_list[i].split('/')[1]
            path_name = uses_list[i].split('/',2)[2]
            result = result + " <a href='/#{classs_name}/#{objectt_name}/newshowall.mobilehtml/#{max_depth}'>[#{i}] #{uses_list[i]}</a>"
          end
        end
      end
      result = result + "<br/>"
      result = result + to_mhtml(mytree[thiskey], the_depth, max_depth)
    end
  end # mytree.is_a? Hash
  if mytree.is_a? Array
    mytree.each_index do |i|
      # write_log "At #{the_depth} found at #{i}" if DEBUG
      the_depth.times do |d|
        the_new_line = the_new_line + "--"
      end
      the_new_line = the_new_line + "[#{i}] #{mytree[i]}"
      the_new_line = the_new_line + "<br/>"
      sub_html = to_mhtml(mytree[i], the_depth, max_depth)
    end
  end # mytree.is_a? Array
  if mytree.is_a? String
    result = result + indent(the_depth) + mytree + "<br/>"
    sub_html = ''
  end
  # write_log "EXITING with #{mytree}" if DEBUG
  result
end

def indent(i)
  result = ''
  i.times do |d|
    result = result + "--"
  end
  result
end
