#!/usr/bin/perl

################################################################################
#
# ログファイルのアーカイブスクリプト
#
# 概要
#   設定ファイルに記載されたファイルをアーカイブ（gzip圧縮）する。
#   日次出力ログ
#   ・過去１ヶ月以前のもの全て圧縮  →  通常ログは３０ファイルのみ残す
#   週次出力ログ
#   ・過去５週以前のもの全て圧縮    →  通常ログは５ファイルのみ残す
#   月次出力ログ
#   ・過去３ヶ月以前のもの全て圧縮  →  通常ログは３ファイルのみ残す
#
#   対象ログファイルや通常ログを残す設定は設定ファイルから読み込む。
#
# 更新履歴
#   2014/10/13 masuto       新規作成
#   2014/10/31 a.tsukakoshi   modify
#
################################################################################

use strict;
use warnings;
use FindBin qw($Bin);
use Switch;
use File::Basename 'fileparse';
use File::Spec;
#use Data::Dumper;

my $conf = "$Bin/archive.conf";

# 設定ファイルの内容
our $configs = {} ;

print "#", getSystemDate(), "\n";

readConfigFile() ;

# 圧縮を行う
foreach my $archiveTarget ('DAILY', 'WEEKLY', 'MONTHLY') {
    my $keepFiles   = $configs->{"$archiveTarget.KEEP.FILES"} ;
    my $targetPaths = $configs->{"$archiveTarget.ARCHIVE.TARGETS"} ;

    # ファイルパス毎に圧縮していく
    foreach my $targetPath (@$targetPaths) {
        executeArchive($keepFiles, $targetPath);
    }
}

# 設定ファイルを読み込む。
# 設定ファイルの形式は以下の形を想定
#
# DAILY.KEEP.FILES=30
# DAILY.ARCHIVE.TARGETS
# /srv/mbos-bat/logs/daily/xxxx1
# /srv/mbos-bat/logs/daily/xxxx2
# WEEKLY.KEEP.FILES=5
# WEEKLY.ARCHIVE.TARGETS
# /srv/mbos-bat/logs/weekly/xxxx1
# /srv/mbos-bat/logs/weekly/xxxx2
# MONTHLY.KEEP.FILES=3
# MONTHLY.ARCHIVE.TARGETS
# /srv/mbos-bat/logs/monthly/xxxx1
# /srv/mbos-bat/logs/monthly/xxxx2
#
# 設定ファイルを読み込んだ結果を %configs に設定する。
# 設定した結果は以下のイメージ
#
# $configs = {
#   'DAILY.KEEP.FILES' => 30 ,
#   'DAILY.ARCHIVE.TARGETS' => [
#       /srv/mbos-bat/logs/daily/xxxx1 ,
#       /srv/mbos-bat/logs/daily/xxxx2 ,
#   ] ,
#   'WEEKLY.KEEP.FILES' => 5 ,
#   'WEEKLY.ARCHIVE.TARGETS' => [
#       /srv/mbos-bat/logs/weekly/xxxx1 ,
#       /srv/mbos-bat/logs/weekly/xxxx2 ,
#   ] ,
#   'MONTHLY.KEEP.FILES' => 3 ,
#   'MONTHLY.ARCHIVE.TARGETS' => [
#       /srv/mbos-bat/logs/monthly/xxxx1 ,
#       /srv/mbos-bat/logs/monthly/xxxx2 ,
#   ] ,
# }
#
# 引数
#   1. なし
# 戻り値
#   1. なし
sub readConfigFile {

    open(CONFIGFILE ,"< $conf")
        or die "設定ファイルが読み込めませんでした。パス=「$conf」\n" ;

    my $configKey   = undef;
    my @values      = () ;
    while(my $line = <CONFIGFILE>) {
        chomp($line);
        $line = trim($line) ;

        # 空行、コメント行はスキップする。
        if ($line =~ /^$/ || $line =~ /^#+/) {
            next ;
        }

        # XXXX.KEEP.FILESに関する処理
        if ($line =~ /^(DAILY|WEEKLY|MONTHLY)\.KEEP\.FILES*/) {
            my @splitValues = split( /=/, $line );
            $configs->{$splitValues[0]} = $splitValues[1] ;
        }
        # XXXX.ARCHIVE.TARGETSに関する処理
        elsif ($line =~ /^(DAILY|WEEKLY|MONTHLY)\.ARCHIVE\.TARGETS*/) {
            # $configKeyの値をチェックして前処理のものと異なっている場合はリストを設定する。
            if (defined($configKey) && $configKey ne $line) {
                $configs->{$configKey} = [@values] ;
                # リストも初期化する
                @values = () ;
            }
            $configKey = $line ;
        } else {
            push(@values, $line);
        }
    }

    # XXXX.ARCHIVE.TARGETSは異なるキーが読み込まれたタイミングで設定しているので
    # 最後のキーがループ内で設定されないので抜けた後に設定する。
    $configs->{$configKey} = [@values] ;
}

# アーカイブ処理を実行する。
# 引数
#   1. 残すファイル数
#   2. アーカイブするファイルパス
# 戻り値
#   1. なし
sub executeArchive {
    my $keepCount   = shift ;
    my $filePath    = shift ;
    my $directoryPath = getFileDirectory($filePath) ;
    my $fileName = getFileName($filePath) ;
    my @targetPaths = () ;
    my $targetCounter = 0 ;


    println("[$directoryPath$fileName]");

    opendir (my $dh, $directoryPath)
        or die "$directoryPath:$!" ;

    while (my $file = readdir $dh) {
        # '.'や'..'の場合はスキップする。
        if ($file =~ /^\.{1,2}$/) {
            next ;
        }

        # カレントファイルや圧縮済みのファイルもスキップする
        if ( $file =~ /.*\.(log|gz|zip)$/ ) {
            next ;
        }

        # 該当名のログファイル以外はスキップする。
        if ( $file !~ /.*$fileName.*/ ) {
            next ;
        }

        # 圧縮対象ファイルリストに追加する。
        push(@targetPaths, $file) ;
    }

    closedir ($dh) ;

    # 対象ファイル数のチェック
    if ($keepCount >= @targetPaths) {
        print("NO FILES TO ARCHIVE. FILES=[", scalar( @targetPaths ), "]\n" );
        return ;
    }

    # 新しいものは圧縮対象外なので、ファイル名降順で並べ替える

     @targetPaths = sort {$b cmp $a} @targetPaths ;

     foreach my $file ( @targetPaths ) {

        # 1ファイル読み込んでいるのでカウントアップ後比較する

        if ($keepCount >= (++ $targetCounter)) {
            next ;
        }

        # 残すファイル数より多いのでアーカイブを行う
        my $targetFile = File::Spec->catfile($directoryPath, $file);

        system("gzip -f $targetFile") ;

        println("zip->$targetFile");
    }
}

# ファイルパスから保存されているファイルのディレクトリを取得する。
# 引数
#   1. ファイルパス
# 戻り値
#   1. ディレクトリパス
sub getFileDirectory {
    my $filePath = shift ;

    my ($base_name, $dir) = fileparse $filePath;

    return $dir;
}


# ファイルパスからファイル名を取得する。
# 引数
#   1. ファイルパス
# 戻り値
#   1. ファイル名
sub getFileName {
    my $filePath = shift ;

    my ($base_name, $dir) = fileparse $filePath;

    return $base_name;
}


# トリム処理。
# スペースだけではなくタブなどの空白文字も削除します。
# 引数
#   1. トリムを掛ける文字列
# 戻り値
#   1. トリムした結果の文字列
sub trim {
    my $val = shift ;
    $val =~ s/^\s*(.*?)\s*$/$1/;
        return $val;
}


# 文字列出力
#   実行時に与えた文字列を一行の文字列として出力します。
# パラメータ
#   1. 出力対象の文字列
sub println {
    my $message = shift;
    print $message . "\n" ;
}

# システム日付を取得する。
# YYYYMMDD形式で返却する。
# 引数
#   なし
# 戻り値
#   1. システム日付(YYYYMMDD)
sub getSystemDate {

    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
    $year += 1900;
    $mon  += 1;

    return sprintf('%04d%02d%02d', $year, $mon, $mday);

}