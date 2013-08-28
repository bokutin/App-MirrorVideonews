1. git clone https://github.com/bokutin/App-MirrorVideonews.git
2. cd App-MirrorVideonews
3. dzil authordeps --missing | cpanm --mirror http://www.cpan.org/ --mirror https://bokut.in/darkpan/
4. dzil listdeps --missing | cpanm
5. cp etc/mirror\_videonews.pl etc/mirror\_videonews\_local.pl 
6. pico etc/mirror\_videonews\_local.pl 
7. ./script/mirror\_videonews.pl
