let limit = 3
let scale value factor =
  let total = value * factor in
  let rec go i acc = if i >= limit then acc else go (i + 1) (acc + i) in
  go 0 total
let twice value =
  let total = value * 2 in (* total in a comment *)
  total
let () = print_endline ("total limit" ^ string_of_int (scale limit 2))
