require 'erb'
require 'rubygems'
require 'rubygems/uninstaller'
require 'rubygems/dependency_installer'

# We only require this in 'rake gems:sync' since
# it contains some advanced Gem features that aren't
# available in earlier versions, such as pre_install_hooks

Gem.pre_install_hooks.push(proc do |installer|
  name = installer.spec.name

  puts "+ #{name}"

  if $GEMS && versions = ($GEMS.assoc(name) || [])[1]
    dep = Gem::Dependency.new(name, versions)
    unless dep.version_requirements.satisfied_by?(installer.spec.version)
      raise "Cannot install #{installer.spec.full_name} " \
            "for #{$INSTALLING}; " \
            "you required #{dep}"
    end
  end
end)

class ::Gem::Uninstaller
  def self._with_silent_ui

    ui = Gem::DefaultUserInteraction.ui
    def ui.say(str)
      puts "- #{str}"
    end

    yield

    class << Gem::DefaultUserInteraction.ui
      remove_method :say
    end
  end

  def self._uninstall(source_index, name, op, version)
    unless source_index.find_name(name, "#{op} #{version}").empty?
      uninstaller = Gem::Uninstaller.new(
        name,
        :version => "#{op} #{version}",
        :install_dir => File.join(Dir.pwd, "vendor", "gems"),
        :all => true,
        :ignore => true,
        :executables => true
      )
      _with_silent_ui { uninstaller.uninstall }
    end
  end

  def self._uninstall_others(source_index, name, version)
    _uninstall(source_index, name, "<", version)
    _uninstall(source_index, name, ">", version)
  end
end

Gem.post_install_hooks.push(proc do |installer|
  source_index = installer.instance_variable_get("@source_index")
  ::Gem::Uninstaller._uninstall_others(
    source_index, installer.spec.name, installer.spec.version
  )
end)

class ::Gem::DependencyInstaller
  alias old_fg find_gems_with_sources

  def find_gems_with_sources(dep)
    if @source_index.any? { |_, installed_spec|
      installed_spec.satisfies_requirement?(dep)
    }
      return []
    end

    old_fg(dep)
  end
end

class ::Gem::SpecFetcher
  alias old_fetch fetch
  def fetch(*args) # in rubygems 1.3.2 fetch takes 4 parameters
    dependency, all, matching_platform, prerelease = *args
    idx = Gem::SourceIndex.from_installed_gems

    reqs = dependency.version_requirements.requirements

    if reqs.size == 1 && reqs[0][0] == "="
      dep = idx.search(dependency).sort.last
    end

    if dep
      file = dep.loaded_from.dup
      file.gsub!(/specifications/, "cache")
      file.gsub!(/gemspec$/, "gem")
      spec = ::Gem::Format.from_file_by_path(file).spec
      [[spec, file]]
    else
      old_fetch(*args)
    end
  end
end

class ::Gem::Specification
  def recursive_dependencies(from, index = Gem.source_index)
    specs = self.runtime_dependencies.map do |dep|
      spec = index.search(dep).last
      unless spec
        raise "Needed #{dep} for #{from}, but could not find it"
      end
      spec
    end
    specs + specs.map {|s| s.recursive_dependencies(self, index)}.flatten.uniq
  end
end