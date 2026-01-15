unit sub MAIN ($file);
$file.IO
andthen .lines
andthen .grep: *.ends-with(',1')
andthen .map: {put $_ ~ ',' ~ <TE TE VA>.pick()}
