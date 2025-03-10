# frozen_string_literal: false

require 'json'
class PluginRoutes
  @@_vars = []
  @@_after_reload = []
  @@anonymous_hooks = {}
  # load plugin routes if it is enabled
  def self.load(env = 'admin')
    plugins = all_enabled_plugins
    res = ''
    case env
    when 'front'
      res << "namespace :plugins do \n"
      plugins.each do |plugin|
        res << "namespace '#{plugin['key']}' do \n"
        begin
          res << "#{File.open(File.join(plugin['path'], 'config', "routes_#{env}.txt")).read}\n"
        rescue StandardError
          ''
        end
        res << "end\n"
      end
      res << "end\n"

    when 'admin' # admin
      res << "scope 'admin', as: 'admin' do \n"
      res << "namespace :plugins do \n"
      plugins.each do |plugin|
        res << "namespace '#{plugin['key']}' do \n"
        begin
          res << "#{File.open(File.join(plugin['path'], 'config', "routes_#{env}.txt")).read}\n"
        rescue StandardError
          ''
        end
        res << "end\n"
      end
      res << "end\n"
      res << "end\n"
    else # main
      plugins.each do |plugin|
        res << "#{File.open(File.join(plugin['path'], 'config', "routes_#{env}.txt")).read}\n"
      rescue StandardError
        ''
      end
    end
    res + load_themes(env)
  end

  def self.load_themes(env = 'admin')
    plugins = all_enabled_themes
    res = ''
    case env
    when 'front'
      res << "namespace :themes do \n"
      plugins.each do |plugin|
        res << "namespace '#{plugin['key']}' do \n"
        begin
          res << "#{File.open(File.join(plugin['path'], 'config', "routes_#{env}.txt")).read}\n"
        rescue StandardError
          ''
        end
        res << "end\n"
      end
      res << "end\n"

    when 'admin' # admin
      res << "scope 'admin', as: 'admin' do \n"
      res << "namespace :themes do \n"
      plugins.each do |plugin|
        res << "namespace '#{plugin['key']}' do \n"
        begin
          res << "#{File.open(File.join(plugin['path'], 'config', "routes_#{env}.txt")).read}\n"
        rescue StandardError
          ''
        end
        res << "end\n"
      end
      res << "end\n"
      res << "end\n"
    else # main
      plugins.each do |plugin|
        res << "#{File.open(File.join(plugin['path'], 'config', "routes_#{env}.txt")).read}\n"
      rescue StandardError
        ''
      end
    end
    res
  end

  class << self
    # return plugin information
    def plugin_info(plugin_key)
      all_plugins.each { |p| return p if p['key'] == plugin_key || p['path'].split('/').last == plugin_key }
      nil
    end

    # return theme information
    # if theme_name is nil, the use current site theme
    def theme_info(theme_name)
      all_themes.each { |p| return p if p['key'] == theme_name }
      nil
    end

    # return system static settings (config.json values)
    def static_system_info
      r = cache_variable('statis_system_info')
      return r unless r.nil?

      settings = {}

      gem_settings = File.join($camaleon_engine_dir, 'config', 'system.json')
      app_settings = Rails.root.join('config', 'system.json')

      settings = settings.merge(JSON.parse(File.read(gem_settings))) if File.exist?(gem_settings)
      settings = settings.merge(JSON.parse(File.read(app_settings))) if File.exist?(app_settings)

      # custom settings
      settings['key'] = 'system'
      settings['path'] = ''
      settings['kind'] = 'system'
      settings['hooks']['on_notification'] ||= []
      cache_variable('statis_system_info', settings)
    end
    alias system_info static_system_info

    # convert action parameter into hash
    def fixActionParameter(h)
      (if h.is_a?(ActionController::Parameters)
         begin
           h.permit!.to_h
         rescue StandardError
           h.to_hash
         end
       else
         h
       end)
    end

    # add a new anonymous hook
    # sample: PluginRoutes.add_anonymous_hook('before_admin', lambda{|params| puts params })
    # @param hook_key [String], key of hook
    # @param hook_id [String], identifier for the anonymous hook
    # @param callback [Lambda], anonymous function to be called when the hook was called
    # @return nil
    def add_anonymous_hook(hook_key, callback, hook_id = '')
      @@anonymous_hooks[hook_key] ||= []
      @@anonymous_hooks[hook_key] << { id: hook_id, callback: callback }
    end

    # return all registered anonymous hooks for hook_key
    # @param hook_key [String] name of the hook
    # @return [Array] array of hooks for hook_key
    def get_anonymous_hooks(hook_key)
      (@@anonymous_hooks[hook_key.to_s] || []).map { |item| item[:callback] }
    end

    # return all registered anonymous hooks for hook_key
    # @param hook_key [String] name of the hook
    # @param hook_id [String] identifier of the anonymous hooks
    # @return [Array] array of hooks for hook_key
    def remove_anonymous_hook(hook_key, hook_id)
      (@@anonymous_hooks[hook_key.to_s] || []).delete_if { |item| item[:id] == hook_id }
    end

    # return the class name for user model
    def get_user_class_name
      static_system_info['user_model'].presence || 'CamaleonCms::User'
    end
  end

  # reload routes
  def self.reload
    @@all_sites = nil
    @@_vars.each { |v| class_variable_set("@@cache_#{v}", nil) }
    Rails.application.reload_routes!
    @@_after_reload.uniq.each { |r| eval(r) }
  end

  # permit to add extra actions for reload routes
  def self.add_after_reload_routes(command)
    @@_after_reload << command
  end

  # return all enabled plugins []
  def self.enabled_plugins(site)
    r = cache_variable("enable_plugins_site_#{site.id}")
    return r unless r.nil?

    res = []
    enabled_ps = site.plugins.active.pluck(:slug)
    all_plugins.each do |plugin|
      res << plugin if enabled_ps.include?(plugin['key'])
    end
    res = res.sort_by { |e| e['position'] || 10 }
    cache_variable("enable_plugins_site_#{site.id}", res)
  end

  # return all enabled apps for site (themes + system + plugins) []
  # theme_slug: current theme slug
  def self.enabled_apps(site, theme_slug = nil)
    theme_slug ||= site.get_theme_slug
    r = cache_variable("enabled_apps_#{site.id}_#{theme_slug}")
    return r unless r.nil?

    res = [system_info] + enabled_plugins(site) + [theme_info(theme_slug)]
    cache_variable("enabled_apps_#{site.id}_#{theme_slug}", res)
  end

  # return all enabled apps as []: system, themes, plugins
  def self.all_enabled_apps
    [system_info] + all_enabled_themes + all_enabled_plugins
  end

  # return all enabled themes (a theme is enabled if at least one site is assigned)
  def self.all_enabled_themes
    r = cache_variable('all_enabled_themes')
    return r unless r.nil?

    res = []
    get_sites.each do |site|
      i = theme_info(site.get_theme_slug)
      res << i if i.present?
    end
    cache_variable('all_enabled_themes', res)
  end

  # return all enabled plugins (a theme is enabled if at least one site has installed)
  def self.all_enabled_plugins
    r = cache_variable('all_enabled_plugins')
    return r unless r.nil?

    res = []
    enabled_ps = []
    get_sites.each { |site| enabled_ps += site.plugins.active.pluck(:slug) }
    all_plugins.each do |plugin|
      res << plugin if enabled_ps.include?(plugin['key'])
    end
    cache_variable('all_enabled_plugins', res)
  end

  # all helpers of enabled plugins for site
  def self.site_plugin_helpers(site)
    r = cache_variable('site_plugin_helpers')
    return r unless r.nil?

    res = []
    enabled_apps(site).each do |settings|
      res += settings['helpers'] if settings['helpers'].present?
    end
    cache_variable('site_plugin_helpers', res)
  end

  # all helpers of enabled plugins
  def self.all_helpers
    r = cache_variable('plugins_helper')
    return r unless r.nil?

    res = []
    all_apps.each do |settings|
      res += settings['helpers'] if settings['helpers'].present?
    end
    cache_variable('plugins_helper', res.uniq)
  end

  # destroy plugin
  def self.destroy_plugin(plugin_key)
    begin
      FileUtils.rm_r(Rails.root.join('app', 'apps', 'plugins', plugin_key))
    rescue StandardError
      ''
    end
    PluginRoutes.reload
  end

  def self.cache_variable(var_name, value = nil)
    @@_vars.push(var_name).uniq!
    # if Rails.env != "development" # disable cache plugin routes for development mode
    cache = begin
      class_variable_get("@@cache_#{var_name}")
    rescue StandardError
      nil
    end
    return cache if value.nil?

    # end
    class_variable_set("@@cache_#{var_name}", value)
    value
  end

  # return all sites registered for Plugin routes
  def self.get_sites
    @@all_sites ||= CamaleonCms::Site.order(id: :asc).all.to_a
  rescue StandardError
    []
  end

  # check if db migrate already done
  def self.db_installed?
    @@is_db_installed ||= ActiveRecord::Base.connection.table_exists?(CamaleonCms::Site.table_name)
  end

  # return all locales for all sites joined by |
  def self.all_locales
    r = cache_variable('site_all_locales')
    return r unless r.nil?

    res = []
    get_sites.each do |s|
      res += s.get_languages
    end
    cache_variable('site_all_locales', res.uniq.join('|'))
  end

  # return all translations for all languages, sample: ['Sample', 'Ejemplo', '....']
  def self.all_translations(key, *args)
    args = args.extract_options!
    all_locales.split('|').map { |_l| I18n.t(key, **args.merge({ locale: _l })) }.uniq
  end

  # return all locales for translated routes
  def self.all_locales_for_routes
    r = cache_variable('all_locales_for_routes')
    return r unless r.nil?

    res = {}
    all_locales.split('|').each do |l|
      res[l] = "_#{l}"
    end
    res[false] = ''
    cache_variable('all_locales_for_routes', res)
  end

  # return apps directory path
  def self.apps_dir
    Rails.root.join('app', 'apps').to_s
  end

  # return all plugins located in cms and in this project
  def self.all_plugins
    camaleon_gem = get_gem('camaleon_cms')
    return [] unless camaleon_gem

    r = cache_variable('all_plugins')
    return r unless r.nil? || r == []

    res = get_gem_plugins
    entries = ['.', '..']
    res.each { |plugin| entries << plugin['key'] }
    (Dir["#{apps_dir}/plugins/*"] + Dir["#{camaleon_gem.gem_dir}/app/apps/plugins/*"]).each do |path|
      entry = path.split('/').last
      config = File.join(path, 'config', 'config.json')
      next if entries.include?(entry) || !File.directory?(path) || !File.exist?(config)

      p = JSON.parse(File.read(config))
      p = begin
        p.with_indifferent_access
      rescue StandardError
        p
      end
      p['key'] = entry
      p['path'] = path
      p['kind'] = 'plugin'
      res << p
      entries << entry
    end
    cache_variable('all_plugins', res)
  end

  # return an array of all themes installed for all sites
  def self.all_themes
    camaleon_gem = get_gem('camaleon_cms')
    return [] unless camaleon_gem

    r = cache_variable('all_themes')
    return r unless r.nil? || r == []

    res = get_gem_themes
    entries = %w[. ..]
    res.each { |theme| entries << theme['key'] }
    Dir["#{apps_dir}/themes/*"].each do |path|
      entry = path.split('/').last
      config = File.join(path, 'config', 'config.json')
      next if entries.include?(entry) || !File.directory?(path) || !File.exist?(config)

      p = JSON.parse(File.read(config))
      p = begin
        p.with_indifferent_access
      rescue StandardError
        p
      end
      p['key'] = entry
      p['path'] = path
      p['kind'] = 'theme'
      p['title'] = p['name']
      res << p
      entries << entry
    end
    cache_variable('all_themes', res)
  end

  # return all apps loaded
  def self.all_apps
    all_plugins + all_themes
  end

  # return all plugins registered as gems
  def self.get_gem_plugins
    entries = []
    Gem::Specification.each do |gem|
      path = gem.gem_dir
      config = File.join(path, 'config', 'camaleon_plugin.json')
      next unless File.exist?(config)

      p = JSON.parse(File.read(config))
      p = begin
        p.with_indifferent_access
      rescue StandardError
        p
      end
      p['key'] = gem.name if p['key'].nil? # TODO: REVIEW ERROR FOR conflict plugin keys
      p['version'] = gem.version.to_s
      p['path'] = path
      p['kind'] = 'plugin'
      p['descr'] = gem.description unless p['descr'].present?
      p['gem_mode'] = true
      entries << p
    end
    entries
  end

  # return all themes registered as gems
  def self.get_gem_themes
    entries = []
    Gem::Specification.each do |gem|
      path = gem.gem_dir
      config = File.join(path, 'config', 'camaleon_theme.json')
      next unless File.exist?(config)

      p = JSON.parse(File.read(config))
      p = begin
        p.with_indifferent_access
      rescue StandardError
        p
      end
      p['key'] = gem.name if p['key'].nil? # TODO: REVIEW ERROR FOR conflict plugin keys
      p['path'] = path
      p['kind'] = 'theme'
      p['gem_mode'] = true
      entries << p
    end
    entries
  end

  # check if a gem is available or not
  # Arguemnts:
  # name: name of the gem
  # return (Boolean) true/false
  def self.get_gem(name)
    Gem::Specification.find_by_name(name)
  rescue Gem::LoadError
    false
  rescue StandardError
    Gem.available?(name)
  end

  # return the default url options for Camaleon CMS
  def self.default_url_options
    options = { host: begin
      CamaleonCms::Site.main_site.slug
    rescue StandardError
      ''
    end }
    options.merge!({ protocol: 'https' }) if Rails.application.config.force_ssl
    options
  end

  def self.migration_class
    ActiveRecord::Migration[4.2]
  end
end
CamaManager = PluginRoutes
