%% Copyright (c) 2018 EMQ Technologies Co., Ltd. All Rights Reserved.
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

-module(emqx_auth_pgsql_app).

-behaviour(application).

-include("emqx_auth_pgsql.hrl").

-import(emqx_auth_pgsql_cli, [parse_query/2]).

%% Application callbacks
-export([start/2, stop/1]).

%%--------------------------------------------------------------------
%% Application callbacks
%%--------------------------------------------------------------------

start(_StartType, _StartArgs) ->
    {ok, Sup} = emqx_auth_pgsql_sup:start_link(),
    if_enabled(auth_query, fun(AuthQuery) ->
        SuperQuery = parse_query(super_query, application:get_env(?APP, super_query, undefined)),
        {ok, HashType}  = application:get_env(?APP, password_hash),
        AuthEnv = {AuthQuery, SuperQuery, HashType},
        ok = emqx_access_control:register_mod(auth, emqx_auth_pgsql, AuthEnv)
    end),
    if_enabled(acl_query, fun(AclQuery) ->
        ok = emqx_access_control:register_mod(acl, emqx_acl_pgsql, AclQuery)
    end),
    emqx_auth_pgsql_cfg:register(),
    {ok, Sup}.

stop(_State) ->
    emqx_access_control:unregister_mod(acl, emqx_acl_pgsql),
    emqx_access_control:unregister_mod(auth, emqx_auth_pgsql),
    emqx_auth_pgsql_cfg:unregister().

if_enabled(Par, Fun) ->
    case application:get_env(?APP, Par) of
        {ok, Query} -> Fun(parse_query(Par, Query));
        undefined   -> ok
    end.

