#!/usr/bin/ruby

# 本地有存在目录（判断podspec是否对应） 则取本地目录 否则取远端
@local = 0
@remote = 1
@remote_original = 2
@remote_branch = 3
@remote_tag = 4
#   本地优先查询 若不在进行远程调用
class PBPodConfiguration

    #   全部项目配置 => { 全部项目配置 }    
    @@all_modules = [
    ]

    #   个人项目配置 => { 门牌 => { 项目名称, 获取方式, 分支，目标， 版本，} } 匹配全部项目配置 个人配置替换全局配置
    @@member_modules = {
    }

    @@member_configs = [
    ]

    def initialize(all_modules, member_modules, member_configs)
        @all_modules = all_modules
        @member_modules = member_modules
        @member_configs = member_configs
    end

    def current_member
        @@member_configs.each do | c |
            puts c
            puts c[:main_path]
            if File.exist?(c[:main_path])
            then
                return c
            else
                c[:pathes].each do | p |
                    if File.exist?(p)
                        return c
                    end
                end
            end
        end

        return nil
    end

    def run

        @run_modules = []
        @target_member_modules = self.current_member

        @@all_modules.each do | m |
            
        end
        # 判断本地目录是否存在获得name

        # 在member_modules中根据name获取对应的配置
        # 在all_modules中判断是否存在对应的配置

    end

end


