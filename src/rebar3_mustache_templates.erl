%% Copyright (c) 2020 Exograd SAS.
%%
%% Permission to use, copy, modify, and/or distribute this software for any
%% purpose with or without fee is hereby granted, provided that the above
%% copyright notice and this permission notice appear in all copies.
%%
%% THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH
%% REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY
%% AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT,
%% INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM
%% LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR
%% OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
%% PERFORMANCE OF THIS SOFTWARE.

-module(rebar3_mustache_templates).

-export([output_path/1, options/2, mustache_context/1,
         render_file/4, render_string/3,
         read_data_file/1]).

-spec output_path(rebar3_mustache:template()) -> file:name_all().
output_path({_, #{output_path := OutputPath}}) ->
  OutputPath;
output_path({InputPath, _}) ->
  %% The default behaviour will generate "name.ext" from "name.ext.mustache"
  %% (or any other final extension).
  case filename:rootname(InputPath) of
    InputPath ->
      %% If the template file path has no extension, we have to find a name to
      %% avoid writing the output over the input file. ".txt" will do.
      filename:flatten([InputPath, ".txt"]);
    OutputPath ->
      OutputPath
  end.

-spec options(rebar3_mustache:template(), rebar3_mustache:config()) ->
        rebar3_mustache:template_options().
options({_, Options}, Config) ->
  %% Start with default mustache options, then merge global options from the
  %% configuration map and and template level options.
  GlobalMustacheOptions = maps:get(mustache_options, Config, #{}),
  TemplateMustacheOptions = maps:get(mustache_options, Options, #{}),
  MustacheOptions = maps:merge(rebar3_mustache:default_mustache_options(),
                               maps:merge(GlobalMustacheOptions,
                                          TemplateMustacheOptions)),
  Options#{mustache_options => MustacheOptions}.

-spec mustache_context(rebar3_mustache:template()) -> mustache:context().
mustache_context({_, Options}) ->
  maps:get(data, Options, #{}).

-spec render_file(file:name_all(), file:name_all(), mustache:context(),
                  rebar3_mustache:template_options()) ->
        ok | {error, term()}.
render_file(InputPath, OutputPath, Context, Options) ->
  MustacheOptions = maps:get(mustache_options, Options,
                             rebar3_mustache:default_mustache_options()),
  case mustache:load_template(InputPath, {file, InputPath}, #{}) of
    {ok, Template} ->
      case mustache:render_template(Template, Context, MustacheOptions) of
        {ok, Data} ->
          case file:write_file(OutputPath, Data) of
            ok ->
              ok;
            {error, Reason} ->
              {error, {write_file, Reason, OutputPath}}
          end;
        {error, Reason} ->
          {error, {render_template, Reason, InputPath}}
      end;
    {error, Reason} ->
      {error, {load_template_file, Reason, InputPath}}
  end.

-spec render_string(binary() | string(), mustache:context(),
                    rebar3_mustache:template_options()) ->
        {ok, binary() | string()} | {error, term()}.
render_string(InputString, Context, Options) ->
  MustacheOptions0 = maps:get(mustache_options, Options,
                              rebar3_mustache:default_mustache_options()),
  MustacheOptions = MustacheOptions0#{return_binary => true},
  TemplateName = if
                   is_binary(InputString) -> InputString;
                   true -> list_to_binary(InputString)
                 end,
  case mustache:load_template(TemplateName, {string, InputString}, #{}) of
    {ok, Template} ->
      case mustache:render_template(Template, Context, MustacheOptions) of
        {ok, Data} ->
          if
            is_binary(InputString) ->
              {ok, Data};
            true ->
              {ok, binary_to_list(Data)}
          end;
        {error, Reason} ->
          {error, {render_template, Reason, TemplateName}}
      end;
    {error, Reason} ->
      {error, {load_template_string, Reason, TemplateName}}
  end.

-spec read_data_file(file:name_all()) ->
        {ok, rebar3_mustache:template_data()} | {error, term()}.
read_data_file(Path) ->
  case file:consult(Path) of
    {ok, Terms} ->
      Data = lists:foldl(fun (Term, Acc) ->
                             maps:merge(Acc, Term) end,
                         #{}, Terms),
      {ok, Data};
    {error, Reason} ->
      {error, {read_file, Reason, Path}}
  end.
