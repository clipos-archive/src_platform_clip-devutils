# SPDX-License-Identifier: LGPL-2.1-or-later
# Copyright © 2007-2018 ANSSI. All Rights Reserved.
package clipvirt;
require Sys::Virt or die 'Install libsys-virt-perl';

use Exporter;
use Term::ANSIColor;
@ISA=qw/Exporter/;
@EXPORT=qw/get_console send_command upload_files new/;
sub new
{
   return bless {port => undef ,dom => undef};
}
sub get_console
{
 my ($self,$domain)=@_;
 my $vmm=Sys::Virt->new(uri=>"qemu:///system");
#@doms=$vmm->list_domains();
 $self->{dom}=$vmm->get_domain_by_name($domain)
 	or die "cannot bind to domain $domain";
 my $st=$vmm->new_stream(Sys::Virt::Stream::NONBLOCK);
 $self->{dom}->open_console($st, undef, 0);
 $self->{console}=$st;
 return $self->{console};
}

#
#
# 	Helper functions : send_command & upload_files
#
#

sub send_command
{
 my $self=shift;
 my $com=shift;
 my $accu;
 #send the command and say it is finished
 chomp $com;
 $com=":" unless($com);
 my $cmd_str="($com) || echo erreur par TOUTATIS; printf 'thisistheend''ofinput'\n";
 $self->{console}->send($cmd_str, length($cmd_str)) or die "send";

 #poll until we see another prompt
 do{
 $count=$self->{console}->recv($string, 1024);
 $accu.=$string;
 #print $i++," ".$accu."\n";
 #print $i++,$accu if($accu);
 } until $accu=~/thisistheendofinput.*#\s*$/sm;

 #cleanup result
 $accu=~s/ //g;
 $accu=~s/\($com\) //;
 $accu=~s/\|\| echo erreur par TOUTATIS; printf 'thisistheend''ofinput'.*?\n//s;
 $accu=~s/thisistheendofinput//is;
 print (colored(['bright_red'],"Something went wrong : "),
      $accu) and return 0 if($accu=~s/erreur par TOUTATIS.*//s and not ($self->{noerrorlog}) );
 return $accu;
#that's all folks
}

sub getfirstfreeletter
{
}

sub upload_files
# synopsis upload_file files remote_path
{
my $self=shift;
my $remotepath=pop @_;
#print "$remotepath\n";
#First create guest volume and upload file inside
my $g=Sys::Guestfs->new();
my $tmp_name=`mktemp`,$sum;
chomp $tmp_name;
#get the size of the files to transfert
$sum+=$_ for (map { -s $_} @_);
$g->disk_create($tmp_name,"raw",$sum*1.1+20*1024*1024);
# to be sure have enought room reserved=5% + (%5+ 2M) for fs structures
$g->add_drive_opts($tmp_name,format => 'raw', readonly=>0);
$g->launch();
(my $disk)=$g->list_devices();
$g->mkfs("ext4",$disk);
$g->mount($disk,"/");
#print for(@_);
$g->upload($_,"/".s/.*\///r) for (@_);
$uuid=$g->vfs_uuid($disk);
$g->close();
print "attach disk\n";
{
  local $SIG{'INT'} = sub { print STDERR "Interrupted";
  $self->{dom}->detach_device("<disk type='block' device='disk'>
       <driver name='qemu' type='raw'/>
       <source dev='$tmp_name'/>
       <target dev='sdb' bus='usb'/>
  </disk>");};
  $self->{dom}->attach_device("<disk type='block' device='disk'>
       <driver name='qemu' type='raw'/>
       <source dev='$tmp_name'/>
       <target dev='sdb' bus='usb'/>
  </disk>");
  # here sdb must not exist BUT it is no the assigned letter inside the guest
  print "mount and cp disk\n";
  $self->send_command("sleep 2\n");
  print "mounting $tmp_name ($uuid) on /mnt\n";
  $self->send_command("mount UUID=$uuid /mnt\n");
  #print $self->send_command("ls /mnt");
  my $copycmd="cp ";
  $copycmd.="/mnt/$_ " for (map {s/.*\///r} @_);
  $self->send_command($copycmd." $remotepath\n");
  print "detach disk...";
}
$self->{dom}->detach_device("<disk type='block' device='disk'>
     <driver name='qemu' type='raw'/>
     <source dev='$tmp_name'/>
     <target dev='sdb' bus='usb'/>
</disk>");#ici modifier pour rechercher pareil
print " done\n";
#system("rm $tmp_name");
}


1;
