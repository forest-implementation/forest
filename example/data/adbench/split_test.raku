unit sub MAIN ($file);
$file.IO
andthen .lines
andthen .grep: *.ends-with(',1')
andthen .pick(*)
andthen .rotor(.elems * 0.66,*)
andthen |.[0] >>~>> ",TE", |.[1] >>~>> ",VA"
andthen .join("\n")
andthen .put