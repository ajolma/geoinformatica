# use this program to create the [Files] list for Geoinformatica.iss
# the run Geoinformatica.iss with Inno Setup 

use Cwd;
use File::Find;

$root = getcwd()."/";
$sub = "Geoinformatica";

open BASE, "base.iss";
@base = <BASE>;
close BASE;

my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
    localtime(time);
$year += 1900;
$mon++;
$mon = "0$mon" if $mon < 10;
$mday = "0$mday" if $mday < 10;
for (@base) {
    s/\$date/$year-$mon-$mday/;
}

open FILES, ">Geoinformatica.iss";
print FILES @base;

finddepth (\&wanted, $sub);

close FILES;


sub wanted {
    return unless -d $_;
    return if $_ eq $sub;
    return if $_ eq 'Output';
    my $d = "$File::Find::dir/$_";
    $d =~ s/\.\///;
    $d =~ s/\//\\/g;
    opendir(DIR, "$root$d") || die "can't opendir $root$d: $!";
    my @files = grep { -f "$root$d\\$_" } readdir(DIR);
    closedir DIR;
    #print scalar(@files),"\n";
    next if @files == 0;
    my $dest = $d;
    $dest =~ s/^$sub//;
    print FILES "Source: \"$d\\*\"; DestDir: \"{app}\\$dest\"\n";
}
