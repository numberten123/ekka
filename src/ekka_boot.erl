%%--------------------------------------------------------------------
%% Copyright (c) 2019 EMQ Technologies Co., Ltd. All Rights Reserved.
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%%--------------------------------------------------------------------

-module(ekka_boot).

-export([ apply_module_attributes/1
        , all_module_attributes/1

        , create_tables/0
        , register_mria_callbacks/0
        ]).

%% @doc Run the hooks to create mnesia tables
create_tables() ->
    ekka_boot:apply_module_attributes(boot_mnesia).

%% @dec Register actions that will be performed during Mria heal
register_mria_callbacks() ->
    mria_config:register_callback(start, fun ekka:start/0),
    mria_config:register_callback(stop, fun ekka:stop/0),
    mria_config:register_callback(core_node_discovery,
                                  fun ekka_autocluster:core_node_discovery_callback/0).

%% only {F, Args}...
apply_module_attributes(Name) ->
    [{Module, [apply(Module, F, Args) || {F, Args} <- Attrs]} ||
        {_App, Module, Attrs} <- all_module_attributes(Name)].

%% Copy from rabbit_misc.erl
all_module_attributes(Name) ->
    Targets =
        lists:usort(
          lists:append(
            [[{App, Module} || Module <- Modules] ||
                {App, _, _}   <- ignore_lib_apps(application:loaded_applications()),
                {ok, Modules} <- [application:get_key(App, modules)]])),
    lists:foldl(
      fun ({App, Module}, Acc) ->
              case lists:append([Atts || {N, Atts} <- module_attributes(Module),
                                         N =:= Name]) of
                  []   -> Acc;
                  Atts -> [{App, Module, Atts} | Acc]
              end
      end, [], Targets).

module_attributes(Module) ->
    case catch Module:module_info(attributes) of
        {'EXIT', {undef, [{Module, module_info, [attributes], []} | _]}} ->
            [];
        {'EXIT', Reason} ->
            exit(Reason);
        V ->
            V
    end.

ignore_lib_apps(Apps) ->
    LibApps = [kernel, stdlib, sasl, appmon, eldap, erts,
               syntax_tools, ssl, crypto, mnesia, os_mon,
               inets, goldrush, gproc, runtime_tools,
               snmp, otp_mibs, public_key, asn1, ssh, hipe,
               common_test, observer, webtool, xmerl, tools,
               test_server, compiler, debugger, eunit, et,
               wx],
    [App || App = {Name, _, _} <- Apps, not lists:member(Name, LibApps)].
