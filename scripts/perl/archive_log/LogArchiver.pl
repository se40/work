#!/usr/bin/perl

################################################################################
#
# ���ե�����Υ��������֥�����ץ�
#
# ����
#   ����ե�����˵��ܤ��줿�ե�����򥢡������֡�gzip���̡ˤ��롣
#   �������ϥ�
#   ������������Τ�����ư���  ��  �̾���ϣ����ե�����Τ߻Ĥ�
#   �������ϥ�
#   �����������Τ�����ư���    ��  �̾���ϣ��ե�����Τ߻Ĥ�
#   ����ϥ�
#   ������������Τ�����ư���  ��  �̾���ϣ��ե�����Τ߻Ĥ�
#
#   �оݥ��ե�������̾����Ĥ����������ե����뤫���ɤ߹��ࡣ
#
# ��������
#   2014/10/13 masuto       ��������
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

# ����ե����������
our $configs = {} ;

print "#", getSystemDate(), "\n";

readConfigFile() ;

# ���̤�Ԥ�
foreach my $archiveTarget ('DAILY', 'WEEKLY', 'MONTHLY') {
    my $keepFiles   = $configs->{"$archiveTarget.KEEP.FILES"} ;
    my $targetPaths = $configs->{"$archiveTarget.ARCHIVE.TARGETS"} ;

    # �ե�����ѥ���˰��̤��Ƥ���
    foreach my $targetPath (@$targetPaths) {
        executeArchive($keepFiles, $targetPath);
    }
}

# ����ե�������ɤ߹��ࡣ
# ����ե�����η����ϰʲ��η�������
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
# ����ե�������ɤ߹������̤� %configs �����ꤹ�롣
# ���ꤷ����̤ϰʲ��Υ��᡼��
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
# ����
#   1. �ʤ�
# �����
#   1. �ʤ�
sub readConfigFile {

    open(CONFIGFILE ,"< $conf")
        or die "����ե����뤬�ɤ߹���ޤ���Ǥ������ѥ�=��$conf��\n" ;

    my $configKey   = undef;
    my @values      = () ;
    while(my $line = <CONFIGFILE>) {
        chomp($line);
        $line = trim($line) ;

        # ���ԡ������ȹԤϥ����åפ��롣
        if ($line =~ /^$/ || $line =~ /^#+/) {
            next ;
        }

        # XXXX.KEEP.FILES�˴ؤ������
        if ($line =~ /^(DAILY|WEEKLY|MONTHLY)\.KEEP\.FILES*/) {
            my @splitValues = split( /=/, $line );
            $configs->{$splitValues[0]} = $splitValues[1] ;
        }
        # XXXX.ARCHIVE.TARGETS�˴ؤ������
        elsif ($line =~ /^(DAILY|WEEKLY|MONTHLY)\.ARCHIVE\.TARGETS*/) {
            # $configKey���ͤ�����å������������Τ�ΤȰۤʤäƤ�����ϥꥹ�Ȥ����ꤹ�롣
            if (defined($configKey) && $configKey ne $line) {
                $configs->{$configKey} = [@values] ;
                # �ꥹ�Ȥ���������
                @values = () ;
            }
            $configKey = $line ;
        } else {
            push(@values, $line);
        }
    }

    # XXXX.ARCHIVE.TARGETS�ϰۤʤ륭�����ɤ߹��ޤ줿�����ߥ󥰤����ꤷ�Ƥ���Τ�
    # �Ǹ�Υ������롼��������ꤵ��ʤ��Τ�ȴ����������ꤹ�롣
    $configs->{$configKey} = [@values] ;
}

# ���������ֽ�����¹Ԥ��롣
# ����
#   1. �Ĥ��ե������
#   2. ���������֤���ե�����ѥ�
# �����
#   1. �ʤ�
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
        # '.'��'..'�ξ��ϥ����åפ��롣
        if ($file =~ /^\.{1,2}$/) {
            next ;
        }

        # �����ȥե�����䰵�̺ѤߤΥե�����⥹���åפ���
        if ( $file =~ /.*\.(log|gz|zip)$/ ) {
            next ;
        }

        # ����̾�Υ��ե�����ʳ��ϥ����åפ��롣
        if ( $file !~ /.*$fileName.*/ ) {
            next ;
        }

        # �����оݥե�����ꥹ�Ȥ��ɲä��롣
        push(@targetPaths, $file) ;
    }

    closedir ($dh) ;

    # �оݥե�������Υ����å�
    if ($keepCount >= @targetPaths) {
        print("NO FILES TO ARCHIVE. FILES=[", scalar( @targetPaths ), "]\n" );
        return ;
    }

    # ��������Τϰ����оݳ��ʤΤǡ��ե�����̾�߽���¤��ؤ���

     @targetPaths = sort {$b cmp $a} @targetPaths ;

     foreach my $file ( @targetPaths ) {

        # 1�ե������ɤ߹���Ǥ���Τǥ�����ȥ��å׸���Ӥ���

        if ($keepCount >= (++ $targetCounter)) {
            next ;
        }

        # �Ĥ��ե���������¿���Τǥ��������֤�Ԥ�
        my $targetFile = File::Spec->catfile($directoryPath, $file);

        system("gzip -f $targetFile") ;

        println("zip->$targetFile");
    }
}

# �ե�����ѥ�������¸����Ƥ���ե�����Υǥ��쥯�ȥ��������롣
# ����
#   1. �ե�����ѥ�
# �����
#   1. �ǥ��쥯�ȥ�ѥ�
sub getFileDirectory {
    my $filePath = shift ;

    my ($base_name, $dir) = fileparse $filePath;

    return $dir;
}


# �ե�����ѥ�����ե�����̾��������롣
# ����
#   1. �ե�����ѥ�
# �����
#   1. �ե�����̾
sub getFileName {
    my $filePath = shift ;

    my ($base_name, $dir) = fileparse $filePath;

    return $base_name;
}


# �ȥ�������
# ���ڡ��������ǤϤʤ����֤ʤɤζ���ʸ���������ޤ���
# ����
#   1. �ȥ���ݤ���ʸ����
# �����
#   1. �ȥ�ष����̤�ʸ����
sub trim {
    my $val = shift ;
    $val =~ s/^\s*(.*?)\s*$/$1/;
        return $val;
}


# ʸ�������
#   �¹Ի���Ϳ����ʸ������Ԥ�ʸ����Ȥ��ƽ��Ϥ��ޤ���
# �ѥ�᡼��
#   1. �����оݤ�ʸ����
sub println {
    my $message = shift;
    print $message . "\n" ;
}

# �����ƥ����դ�������롣
# YYYYMMDD�������ֵѤ��롣
# ����
#   �ʤ�
# �����
#   1. �����ƥ�����(YYYYMMDD)
sub getSystemDate {

    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
    $year += 1900;
    $mon  += 1;

    return sprintf('%04d%02d%02d', $year, $mon, $mday);

}