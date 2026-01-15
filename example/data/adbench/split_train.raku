unit sub MAIN ($file);
$file.IO
andthen .lines
andthen .grep: *.ends-with(',0')
andthen .map: {put $_ ~ ',' ~ (|('TR' xx 7), |('TA' xx 2), 'VA').pick()}
