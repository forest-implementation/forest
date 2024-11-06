unit sub MAIN ($file);
$file.IO
andthen .lines
andthen .grep: *.ends-with(',0')
andthen .pick(*)
andthen .rotor(.elems * 0.7,.elems * 0.2, *)
andthen |.[0] >>~>> ",TR", |.[1] >>~>> ",TE", |.[2] >>~>> ",VA"
andthen .join("\n")
andthen .put