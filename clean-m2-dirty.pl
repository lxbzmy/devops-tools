#!/usr/bin/perl

use strict;
use warnings;
use File::Find;
use Getopt::Long;
use File::Temp qw(tempdir);
use File::Copy qw(move);
use File::Basename qw(basename dirname);
use File::Spec;
use File::Path qw(make_path);

# 解析命令行参数
my $dry_run = 0;
GetOptions('dry-run' => \$dry_run);

# 找到 m2/repository 目录
my $repo_path = $ENV{HOME} . '/.m2/repository';

# 检查目录是否存在
unless (-d $repo_path) {
    die "在 $repo_path 未找到 Maven 仓库\n";
}

print "正在扫描 Maven 仓库 $repo_path 以查找没有 POM 文件的目录...\n";

# 哈希表用于跟踪哪些目录是垃圾
my %is_garbage;

# 判断目录是否缺少必须的制品文件
# 可能的情况，pom jar war zip gz 
sub is_without_pom_and_jar {
    my ($entries_ref) = @_;
    return !(grep { /\.pom$/ || /\.jar$/ || /\.gz$/ || /\.war$/ || /\.zip$/ } @$entries_ref);
}

# 判断该目录是否已有垃圾祖先，避免重复搬运子目录
sub has_garbage_ancestor {
    my ($dir, $garbage_ref) = @_;
    my $parent = dirname($dir);
    while ($parent && $parent ne '/' && $parent ne $repo_path) {
        return 1 if $garbage_ref->{$parent};
        $parent = dirname($parent);
    }
    return 0;
}



# 遍历目录
find(\&check_directory, $repo_path);

sub check_directory {
    # 只处理目录
    return unless -d $_;

    my $current_dir = $File::Find::name;

    # 跳过根目录
    return if $current_dir eq $repo_path;

    # 打开目录并读取内容
    opendir(my $dh, $current_dir) or return;
    my @files = grep { !/^\.\.?$/ } readdir($dh);
    closedir($dh);

    # 检查是否包含 .pom 或 .jar
    my $missing_pom_and_jar = is_without_pom_and_jar(\@files);

    # 获取子目录列表
    my @subdirs = grep { -d "$current_dir/$_" } @files;

    if (@subdirs == 0) {
        # 叶子目录：没有子目录
        if ($missing_pom_and_jar) {
            $is_garbage{$current_dir} = 1;
            print "垃圾目录: $current_dir\n";
        }
    } else {
        # 非叶子目录：检查所有子目录是否都是垃圾
        my $all_sub_garbage = 1;
        foreach my $sub (@subdirs) {
            my $sub_path = "$current_dir/$sub";
            if (!$is_garbage{$sub_path}) {
                $all_sub_garbage = 0;
                last;
            }
        }
        if ($all_sub_garbage && $missing_pom_and_jar) {
            $is_garbage{$current_dir} = 1;
            print "垃圾目录: $current_dir\n";
        }
    }
}

if ($dry_run) {
    print "试运行完成。没有移动任何文件。\n";
} else {
    # 仅移动最顶层的垃圾目录，避免子目录被重复移动
    my @garbage_roots = sort { length($a) <=> length($b) } keys %is_garbage;
    @garbage_roots = grep { !has_garbage_ancestor($_, \%is_garbage) } @garbage_roots;

    # 创建临时目录
    my $temp_dir = tempdir('m2-garbage-XXXXXX', TMPDIR => 1, CLEANUP => 0);
    print "正在将垃圾目录移动到 $temp_dir\n";

    foreach my $dir (@garbage_roots) {
        next unless -d $dir;
        my $rel_path = File::Spec->abs2rel($dir, $repo_path);
        my $target = File::Spec->catfile($temp_dir, $rel_path);
        my $target_parent = dirname($target);
        make_path($target_parent) unless -d $target_parent;
        if (move($dir, $target)) {
            #print "已将 $dir 移动到 $target\n";
        } else {
            warn "移动 $dir 失败: $!\n";
        }
    }

    # 清理残留的空目录
    print "正在清理残留的空目录...\n";
    system("find", "$repo_path", "-type", "d", "-empty", "-delete");

    print "所有垃圾目录已移动到 $temp_dir。请检查并根据需要删除。\n";
}

