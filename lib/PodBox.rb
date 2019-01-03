#!/usr/bin/ruby
require 'uri'
# 参数
# :name, :names,
# :git, :git_format,
# :root_path, :path, :path_format,
# :branch, :tag, :version,
# :method,

# 使用说明 
# 如果有method 则使用method对应的方式请求模块
# 如果配置中数据匹配对应method失败 则使用默认规则
# method            { (必选参数), [ 可选参数 ] }
# DEFAULT           LOCAL
# LOCAL             { ( (:name || :names),), [:path, :root_path, :path_format] }
# REMOTE_GIT        { ( (:name || :names), :git), [:git_format] }
# REMOTE_VERSION    { ( (:name || :names), :git), [:version] }
# REMOTE_BRANCH     { ( (:name || :names), :git), [:branch='master'] }
# REMOTE_TAG        { ( (:name || :names), :git, :tag), [] }

# 默认规则 
# 如果配置中有git地址， 优先使用git地址， 
# 如果git地址不存在， 则根据名字判断本地模块目录(当前用户模块根目录地址+模块名字)是否存在,
# 如果本地模块根目录存在, 则LOCAL（pod 'name' :path => 'path'） 
# 如果本地模块根目录不存在 则REMOTE_VERSION（pod 'name' || pod 'name' 'version'）
# DEFAULT           LOCAL
# LOCAL             ( pod 'name' :path => 'path' )
# REMOTE_GIT        ( pod 'name' :git => 'git' :branch => 'master' )
# REMOTE_VERSION    ( pod 'name' || pod 'name' 'version')
# REMOTE_BRANCH     ( pod 'name' :git => 'git' :branch => 'branch' )
# REMOTE_TAG        ( pod 'name' :git => 'git' :tag => 'tag' )

# method
DEFAULT = 0
LOCAL = 1
REMOTE_GIT = 2
REMOTE_VERSION = 3
REMOTE_BRANCH = 4
REMOTE_TAG = 5

#   本地优先查询 若不在进行远程调用
class PBPodModule

    #   全部项目配置 => { 全部项目配置 }    
    @@all_modules = [
    ]

    #   个人项目配置 => { 门牌 => { 项目名称, 获取方式, 分支，目标， 版本，} } 匹配全部项目配置 个人配置替换全局配置
    @@member_modules = {
    }

    #   成员配置 => { 门牌 => { 项目名称, 获取方式, 分支，目标， 版本，} } 匹配全部项目配置 个人配置替换全局配置
    @@member_configs = [
    ]

    def initialize(all_modules, member_modules, member_configs)
        @@all_modules = all_modules
        @@member_modules = member_modules
        @@member_configs = member_configs
    end

    def current_member
        @@member_configs.each do | c |
            c[:pathes].each do | p |
                if File.exist?(p)
                    return c
                end
            end
        end
        return nil
    end

    def current_member_modules
        @current_member = self.current_member
        @current_member_modules = []
        @@member_modules[current_member[:name]].each do | m |
            @current_member_modules << m
        end
        return @current_member_modules
    end

    def current_all_modules
        return @@all_modules
    end

end



# 从列表中搜索得到对应配置
def module_for_name(name, module_list)

    module_list.each do | m |
        if name == m[:name]
            return m
        else 
            m[:names].each do | n |
                if n == name
                    return m
                end
            end
        end 
    end

    return nil
end

# 默认配置key
def default_module_keys
    return [
        :name,
        :names,
        :git,
        :git_format,
        :root_path,
        :path,
        :path_format,
        :branch,
        :tag,
        :version,
        :method,
    ]
end


# 获取需要的对应key的值
def value_from_module(source_module, target_module, key)

    if target_module == nil || source_module == nil || key == nil || key.length == nil
        return nil
    end

    source_value = source_module[key]
    target_value = target_module[key]
    if target_value == nil
        return source_value 
    else
        return target_value
    end
    
end


# 根据请求方式调整配置 如果明确指定了方法 则使用方法 否则 使用默认方法（如果本地存在对应的项目地址就请求，否则就请求git仓库，否则报错）
def module_with_method(method=DEFAULT, source_module, current_member)

    if source_module == nil
        return nil
    end
    
    if method == nil 
        method = DEFAULT
    end
    
    name = source_module[:name]
    git_name = name
    if name != nil && name.split("/") != nil && name.split("/").length > 0
        git_name = name.split("/")[0]
    end
    
    name_condition = (name != nil && name.length > 0)
    if name_condition == false
        return nil
    end
    
    git = source_module[:git]
    git_condition = (source_module[:git] != nil && source_module[:git].length > 0)
    git_format_condition = (source_module[:git_format] != nil && source_module[:git_format].length > 0)
    if git_condition
        git = git
    elsif git_format_condition
        git = source_module[:git_format].gsub(/\#\{git_name\}/, "\#\{git_name\}" => git_name)
    else
        git = nil
    end

    path = source_module[:path]
    root_path_condition = (source_module[:root_path] != nil && source_module[:root_path].length > 0)
    path_condition = (path != nil && path.length > 0)
    path_format_condition = (source_module[:path_format] != nil && source_module[:path_format].length > 0)
    if path_condition
        path = path
    elsif path_format_condition
        path = source_module[:path_format].gsub(/\#\{git_name\}/, "\#\{git_name\}" => git_name)
    elsif root_path_condition
        path = File.join(source_module[:root_path], git_name)
    else
        path = nil
        if current_member[:force_local] == true
            current_member[:pathes].each do | p |
                if File.exist?(File.join(p, git_name))
                    path = File.join(p, git_name)
                end
            end
        end
    end
    
    branch = source_module[:branch]
    branch_condition = (branch != nil && branch.length > 0)
    
    tag = source_module[:tag]
    tag_condition = (tag != nil && tag.length > 0)
    
    version = source_module[:version]
    version_condition = (version != nil && version.length > 0)
    
    target_method = DEFAULT
    if path != nil && path.length > 0
        if File.exist?(path)
            target_method = LOCAL
        else
            target_method = REMOTE_VERSION
        end
    elsif git != nil && git.length > 0
        if branch_condition
            target_method = REMOTE_BRANCH
        elsif tag_condition
            target_method = REMOTE_TAG
        else
            target_method = REMOTE_GIT
        end
    elsif version_condition
        target_method = REMOTE_VERSION
    else
        if path == nil || path.length == 0
            current_member[:pathes].each do | p |
                if File.exist?(File.join(p, git_name))
                    path = File.join(p, git_name)
                end
            end
        end
        
        if path != nil && path.length > 0
            target_method = LOCAL
        else
            target_method = REMOTE_VERSION
        end
    end

    case method
    when DEFAULT
        # 根据参数判断method
        if target_method != DEFAULT
            module_with_method(target_method, source_module, current_member)
        else
            module_with_method(LOCAL, source_module, current_member)
        end
    when LOCAL
        if ( path != nil && path.length > 0 ) 
            if File.exist?(path)
                pod "#{name}", :path => "#{path}"
            end
        else
            module_with_method(REMOTE_VERSION, source_module, current_member)
        end
    when REMOTE_GIT
        if ( git != nil && git.length > 0 )
            puts "#{name} branch=>master, #{source_module}"
            pod "#{name}", :git => "#{git}", :branch => 'master'
        else
            module_with_method(LOCAL, source_module, current_member)
        end
    when REMOTE_VERSION
        if ( version != nil && version.length > 0 )
            pod "#{name}", "#{version}"
        else
            pod "#{name}"
        end
    when REMOTE_BRANCH
        if ( git != nil && git.length > 0 ) && ( branch != nil && branch.length > 0 )
            pod "#{name}", :git => "#{git}", :branch => "#{branch}"
        else
            module_with_method(LOCAL, source_module, current_member)
        end
    when REMOTE_TAG
        if ( git != nil && git.length > 0 ) && ( tag != nil && tag.length > 0 )
            pod "#{name}", :git => "#{git}", :tag => "#{tag}"
        else
            module_with_method(LOCAL, source_module, current_member)
        end
    else
        module_with_method(LOCAL, source_module, current_member)
    end
end

# 整合两个配置
def combine_modules(source_module, target_module, target_name, current_member)

    if ( target_module == nil && source_module == nil ) && ( target_name == nil || target_name.length == nil )
        return nil
    end
    
    source_module_name_condition = ( source_module != nil && source_module[:name] == target_name )
    target_module_name_condition = ( target_module != nil && target_module[:name] == target_name )
    source_module_names_condition = ( source_module != nil && source_module[:names].include?(target_name) )
    target_module_names_condition = ( target_module != nil && target_module[:names].include?(target_name) )
    # 符合名字都在两个配置里
    condition = ( source_module_name_condition && target_module_name_condition && source_module_names_condition && target_module_names_condition )
    the_module = target_module
    if condition
        the_module = target_module
    else
        if target_module_name_condition || target_module_names_condition
            the_module = target_module
        elsif source_module_name_condition || source_module_names_condition
            the_module = source_module
        end
    end
    returned_module = {}
    default_module_keys = default_module_keys()
    default_module_keys.each do | key |
        returned_module[key] = value_from_module(returned_module, the_module, key)
    end
    
    returned_module[:names] = []
    returned_module[:name] = target_name
    method = returned_module[:method]
    if method == nil
        method = DEFAULT
    end
    returned_module = module_with_method(method, returned_module, current_member)
    return returned_module
end


def pod_box_module_run(pod_module)
    @run_modules = []
    # 获取当前成员信息
    @current_member = pod_module.current_member
    # 获取成员信息对应的配置列表
    @current_member_modules = pod_module.current_member_modules

    # 获取全部需要执行的模块
    pod_module.current_all_modules.each do | m |
        name = m[:name]
        mod = nil
        if name == nil || name.length == 0
            m[:names].each do | n |
                name = n
                source_module = m
                target_module = nil
                if @current_member != nil && @current_member[:force_local] == true
                    target_module = module_for_name(n, @current_member_modules)
                end
                mod = combine_modules(source_module, target_module, name, @current_member)
            end
        else
            target_module = module_for_name(n, @current_member_modules)
            combine_modules(source_module, target_module, name, @current_member)
        end
    end
end
