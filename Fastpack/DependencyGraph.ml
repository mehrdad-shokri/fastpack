module StringSet = Set.Make(String)

type t = {
  modules : (string, Module.t) Hashtbl.t;
  dependencies : (string, (Dependency.t * Module.t option)) Hashtbl.t;
}

let iter_modules iter graph =
  Hashtbl.iter iter graph.modules

let get_modules graph =
  Hashtbl.keys_list graph.modules

let empty ?(size=5000) () = {
  modules = Hashtbl.create size;
  dependencies = Hashtbl.create (size * 20);
}

let lookup table key =
  Hashtbl.find_opt table key

let lookup_module graph filename =
  lookup graph.modules filename

let lookup_dependencies graph (m : Module.t) =
  Hashtbl.find_all graph.dependencies m.filename

let add_module graph (m : Module.t) =
  if Hashtbl.mem graph.modules m.filename
  then Hashtbl.remove graph.modules m.filename;
  Hashtbl.add graph.modules m.filename m

let add_dependency graph (m : Module.t) (dep : (Dependency.t * Module.t option)) =
  Hashtbl.add graph.dependencies m.filename dep;


exception Cycle of string list

let sort graph entry =
  let modules = ref [] in
  let seen_globally = ref (StringSet.empty) in
  let add_module m =
    modules := m :: !modules;
    seen_globally := StringSet.add m.Module.filename !seen_globally
  in
  let check_module m =
    StringSet.mem m.Module.filename !seen_globally
  in
  let rec sort seen m =
    match List.mem m.Module.filename seen with
    | true ->
      let prev_m =
        match lookup_module graph (List.hd seen) with
        | Some prev_m -> prev_m
        | None -> Error.ie "DependencyGraph.sort - imporssible state"
      in
      if m.Module.es_module && prev_m.Module.es_module
      then ()
      else
        let filenames = m.Module.filename :: seen in
        raise (Cycle filenames)
    | false ->
      match check_module m with
      | true -> ()
      | false ->
        let sort' = sort (m.Module.filename :: seen) in
        let () =
          List.iter
            sort'
            (List.filter_map (fun (_, m) -> m) (lookup_dependencies graph m))
        in
          add_module m;
  in
  begin
    sort [] entry;
    List.rev !modules
  end
