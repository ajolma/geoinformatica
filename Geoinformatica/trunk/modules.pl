opendir(DIR, 'c:/dev/CPAN');
@d = readdir (DIR);
closedir DIR;
for (sort @d) {
    next unless /^[A-W]/;
    next if /^Test/;
    print "$_\n";
}
