#lang scribble/rhombus/manual
@(import:
    "common.rhm" open
    lib("rhombus/private/module-path.rkt")!#{for-meta}.modpath)

@title{Export}

@doc(
  decl.nestable_macro 'export:
                         $export_clause
                         ...'

  decl.nestable_macro 'export $export_clause'

  grammar export_clause:
    apple
    $export_item
    $export_item:
      $modifier
      ...
    $modifier:
      $export_clause
      ...

  grammar export_item:
    $identifier_or_operator
    $export

  grammar identifier_or_operator:
    $identifier_path
    $operator_path
){

 Exports from the enclosing module or namespace. An @rhombus(export) form with a
 single immediate @rhombus(export_clause) is shorthand for an
 @rhombus(export) form that has a block containing the single
 @rhombus(export_clause).
 
 An @rhombus(export_item) can be an identifier, operator, other export
 form, such as @rhombus(all_from, ~expo).
 It can also be a sequence @rhombus(export_item)s within a
 group, since @rhombus(#%juxtapose, ~expo) is defined as an
 export form.

 Similar to @rhombus(import), an @rhombus(export_item) can be modified
 either through a subsequent block containing @rhombus(modifier)s or
 by a preceding @rhombus(modifier) with the @rhombus(export_item)s in
 a block. The latter order works only if the @rhombus(modifier) itself
 does not need a block.

 An @rhombus(identifier_path) or @rhombus(operator_path) export can be
 an immediate identifier or oerator, or it can be dotted name, such as
 @rhombus(List.length). The last component of a dotted name is used as
 the export name. See @secref("namespaces") for information on
 @rhombus(identifier_path) and @rhombus(operator_path).

}

@doc(
  expo.macro 'all_from($module_path)'
  expo.macro 'all_from(#,(@rhombus(., ~expo)) $identifier_path)'
){

 With @rhombus(module_path), exports all bindings imported without a
 prefix from @rhombus(module_path), where @rhombus(module_path) appears
 the same via @rhombus(import). ``The same''
 means that the module paths are the same after some normalization: paths
 that use @rhombus(/)-separated indentifiers are converted to
 @rhombus(lib) forms, and in a @rhombus(lib) form, an implicit
 @filepath{.rhm} suffix is made explicit.

 With @rhombus(#,(@rhombus(., ~expo)) identifier_path), exports
 the content of the specified @tech{namespace} or module import (i.e.,
 the content that would be accessed with a prefix in the exporting
 context). See @secref("namespaces") for information on
 @rhombus(identifier_path).
}

@doc(
  expo.macro 'rename:
                $int_identifier_or_operator #,(@rhombus(as, ~expo)) $ext_identifier_or_operator
                ...'
){

 For each @rhombus(as, ~expo) group, exports
 @rhombus(int_identifier_or_operator) bound locally so that it's
 imported as @rhombus(ext_identifier_or_operator).

}

@doc(
  expo.macro 'names:
                $identifier_or_operator ...
                ...'
){

 Exports all @rhombus(identifier_or_operator)s.

 Most @rhombus(identifier_or_operator)s can be exported directly
 without using @rhombus(names, ~impo), but the @rhombus(names, ~impo)
 form disambiguates in the case of an @rhombus(identifier_or_operator) that is
 itself bound as an export form or modifier.

}

@doc(
  expo.macro '$export #%juxtapose $export'
){

 Exports the union of bindings described by the two @rhombus(export)s.

 @see_implicit(@rhombus(#%juxtapose, ~expo), "an export", "export", ~is_infix: #true)

}

@doc(
  expo.macro 'as'
){

 Invalid by itself, and intended for use with @rhombus(rename, ~expo).

}

@doc(
  expo.modifier 'except $export'
  expo.modifier 'except:
                  $export
                  ...'
){

 Modifies an export to remove the identifiers that would be exported
 by the @rhombus(export)s.

}

@doc(
  expo.modifier 'meta',
  expo.modifier 'meta $phase'
){

 Modifies exports to apply at @rhombus(phase) more than the enclosing
 context's phase, where @rhombus(phase) defaults to @rhombus(1).

 This modifier is valid only immediately within a modules, and not
 within @rhombus(namespace) forms.

}

@doc(
  expo.modifier 'meta_label'
){

 Modifies exports to apply at the label phase.

 This modifier is valid only immediately within a modules, and not
 within @rhombus(namespace) forms.

}

@doc(
  expo.macro '$identifier_path . $identifier'
  expo.macro '$identifier_path . ($operator)'
){

  In an export clause, @rhombus(., ~expo) can be used only to form a
  and @rhombus(identifier_path, ~var) or @rhombus(operator_path, ~var)
  as described for @rhombus(export). It can also be used to form an
  @rhombus(identifier_path, ~var) for @rhombus(all_from).

}


@doc(
  modpath.macro '$identifier / $collection_module_path'
){

 Like the @rhombus(/, ~impo) operator for @rhombus(import) module
 paths, used for module paths in @rhombus(all_from, ~expo).

}


@doc(
  modpath.macro 'lib($string)'
){

 Like the @rhombus(lib, ~impo) form for @rhombus(import), used for
 module paths in @rhombus(all_from, ~expo).

}


@doc(
  modpath.macro 'file($string)'
){

 Like the @rhombus(file, ~impo) form for @rhombus(import), used for
 module paths in @rhombus(all_from, ~expo).

}


@doc(
  modpath.macro '$module_path ! $identifier'
){

 Like the @rhombus(!, ~impo) operator for @rhombus(import) to access a
 submodule, used for module paths in @rhombus(all_from, ~expo).

}

@doc(
  modpath.macro 'self'
  modpath.macro 'parent'
){

 Like the @rhombus(self, ~impo) and @rhombus(parent, ~impo)
 @rhombus(import) forms, used for module paths in
 @rhombus(all_from, ~expo).

}


@doc(
  expo.modifier 'only_space $identifier'
  expo.modifier 'only_space: $identifier ...'
  expo.modifier 'except_space $identifier'
  expo.modifier 'except_space: $identifier ...'
){

 Modifies an @rhombus(export) clause to include bindings only in the
 specifically listed @tech{spaces} or only in the spaces not specifically
 listed.

}
