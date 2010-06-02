%% The MIT License

%% Copyright (c) 2010 Alisdair Sullivan <alisdairsullivan@yahoo.ca>

%% Permission is hereby granted, free of charge, to any person obtaining a copy
%% of this software and associated documentation files (the "Software"), to deal
%% in the Software without restriction, including without limitation the rights
%% to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
%% copies of the Software, and to permit persons to whom the Software is
%% furnished to do so, subject to the following conditions:

%% The above copyright notice and this permission notice shall be included in
%% all copies or substantial portions of the Software.

%% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
%% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
%% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
%% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
%% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
%% OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
%% THE SOFTWARE.

-module(jsx_utf32le).
-author("alisdairsullivan@yahoo.ca").

-include("jsx_common.hrl").

-export([start/4]).

-define(encoding, utf32-little).


%% callbacks to our handler are roughly equivalent to a fold over the events, incremental
%%   rather than all at once.    

fold(end_of_stream, {F, State}) ->
    F(end_of_stream, State);
fold(Event, {F, State}) when is_function(F) ->
    {F, F(Event, State)}.


%% this code is mostly autogenerated and mostly ugly. apologies. for more insight on
%%   Callbacks or Opts, see the comments accompanying decoder/2 (in jsx.erl). Stack 
%%   is a stack of flags used to track depth and to keep track of whether we are 
%%   returning from a value or a key inside objects. all pops, peeks and pushes are 
%%   inlined. the code that handles naked values and comments is not optimized by the 
%%   compiler for efficient matching, but you shouldn't be using naked values or comments 
%%   anyways, they are horrible and contrary to the spec.

start(<<S/?encoding, Rest/binary>>, Stack, Callbacks, Opts) when ?is_whitespace(S) -> 
    start(Rest, Stack, Callbacks, Opts);
start(<<?start_object/?encoding, Rest/binary>>, Stack, Callbacks, Opts) ->
    object(Rest, [key|Stack], fold(start_object, Callbacks), Opts);
start(<<?start_array/?encoding, Rest/binary>>, Stack, Callbacks, Opts) ->
    array(Rest, [array|Stack], fold(start_array, Callbacks), Opts);
start(<<?quote/?encoding, Rest/binary>>, Stack, Callbacks, Opts) ->
    string(Rest, Stack, Callbacks, Opts, []);
start(<<$t/?encoding, Rest/binary>>, Stack, Callbacks, Opts) ->
    tr(Rest, Stack, Callbacks, Opts);
start(<<$f/?encoding, Rest/binary>>, Stack, Callbacks, Opts) ->
    fa(Rest, Stack, Callbacks, Opts);
start(<<$n/?encoding, Rest/binary>>, Stack, Callbacks, Opts) ->
    nu(Rest, Stack, Callbacks, Opts);
start(<<?negative/?encoding, Rest/binary>>, Stack, Callbacks, Opts) ->
    negative(Rest, Stack, Callbacks, Opts, "-");
start(<<?zero/?encoding, Rest/binary>>, Stack, Callbacks, Opts) ->
    zero(Rest, Stack, Callbacks, Opts, "0");
start(<<S/?encoding, Rest/binary>>, Stack, Callbacks, Opts) when ?is_nonzero(S) ->
    integer(Rest, Stack, Callbacks, Opts, [S]);
start(<<?solidus/?encoding, Rest/binary>>, Stack, Callbacks, ?comments_enabled(Opts)) ->
    maybe_comment(Rest, fun(Resume) -> start(Resume, Stack, Callbacks, Opts) end);
start(Bin, Stack, Callbacks, Opts) when byte_size(Bin) < 4 ->
    {incomplete, fun(Stream) -> start(<<Bin/binary, Stream/binary>>, Stack, Callbacks, Opts) end}.


maybe_done(<<S/?encoding, Rest/binary>>, Stack, Callbacks, Opts) when ?is_whitespace(S) ->
    maybe_done(Rest, Stack, Callbacks, Opts);
maybe_done(<<?end_object/?encoding, Rest/binary>>, [object|Stack], Callbacks, Opts) ->
    maybe_done(Rest, Stack, fold(end_object, Callbacks), Opts);
maybe_done(<<?end_array/?encoding, Rest/binary>>, [array|Stack], Callbacks, Opts) ->
    maybe_done(Rest, Stack, fold(end_array, Callbacks), Opts);
maybe_done(<<?comma/?encoding, Rest/binary>>, [object|Stack], Callbacks, Opts) ->
    key(Rest, [key|Stack], Callbacks, Opts);
maybe_done(<<?comma/?encoding, Rest/binary>>, [array|_] = Stack, Callbacks, Opts) ->
    value(Rest, Stack, Callbacks, Opts);
maybe_done(<<?solidus/?encoding, Rest/binary>>, Stack, Callbacks, ?comments_enabled(Opts)) ->
    maybe_comment(Rest, fun(Resume) -> maybe_done(Resume, Stack, Callbacks, Opts) end);
maybe_done(<<>>, [], Callbacks, Opts) ->
    {fold(end_of_stream, Callbacks), fun(Stream) -> maybe_done(Stream, [], Callbacks, Opts) end};
maybe_done(Bin, Stack, Callbacks, Opts) when byte_size(Bin) < 4 ->
    {incomplete, fun(Stream) -> maybe_done(<<Bin/binary, Stream/binary>>, Stack, Callbacks, Opts) end}.


object(<<S/?encoding, Rest/binary>>, Stack, Callbacks, Opts) when ?is_whitespace(S) ->
    object(Rest, Stack, Callbacks, Opts);
object(<<?quote/?encoding, Rest/binary>>, Stack, Callbacks, Opts) ->
    string(Rest, Stack, Callbacks, Opts, []);
object(<<?end_object/?encoding, Rest/binary>>, [key|Stack], Callbacks, Opts) ->
    maybe_done(Rest, Stack, fold(end_object, Callbacks), Opts);
object(<<?solidus/?encoding, Rest/binary>>, Stack, Callbacks, ?comments_enabled(Opts)) ->
    maybe_comment(Rest, fun(Resume) -> object(Resume, Stack, Callbacks, Opts) end);
object(Bin, Stack, Callbacks, Opts) when byte_size(Bin) < 4 ->
    {incomplete, fun(Stream) -> object(<<Bin/binary, Stream/binary>>, Stack, Callbacks, Opts) end}.


array(<<S/?encoding, Rest/binary>>, Stack, Callbacks, Opts) when ?is_whitespace(S) -> 
    array(Rest, Stack, Callbacks, Opts);       
array(<<?quote/?encoding, Rest/binary>>, Stack, Callbacks, Opts) ->
    string(Rest, Stack, Callbacks, Opts, []);
array(<<$t/?encoding, Rest/binary>>, Stack, Callbacks, Opts) ->
    tr(Rest, Stack, Callbacks, Opts);
array(<<$f/?encoding, Rest/binary>>, Stack, Callbacks, Opts) ->
    fa(Rest, Stack, Callbacks, Opts);
array(<<$n/?encoding, Rest/binary>>, Stack, Callbacks, Opts) ->
    nu(Rest, Stack, Callbacks, Opts);
array(<<?negative/?encoding, Rest/binary>>, Stack, Callbacks, Opts) ->
    negative(Rest, Stack, Callbacks, Opts, "-");
array(<<?zero/?encoding, Rest/binary>>, Stack, Callbacks, Opts) ->
    zero(Rest, Stack, Callbacks, Opts, "0");
array(<<S/?encoding, Rest/binary>>, Stack, Callbacks, Opts) when ?is_nonzero(S) ->
    integer(Rest, Stack, Callbacks, Opts, [S]);
array(<<?start_object/?encoding, Rest/binary>>, Stack, Callbacks, Opts) ->
    object(Rest, [key|Stack], fold(start_object, Callbacks), Opts);
array(<<?start_array/?encoding, Rest/binary>>, Stack, Callbacks, Opts) ->
    array(Rest, [array|Stack], fold(start_array, Callbacks), Opts);
array(<<?end_array/?encoding, Rest/binary>>, [array|Stack], Callbacks, Opts) ->
    maybe_done(Rest, Stack, fold(end_array, Callbacks), Opts);
array(<<?solidus/?encoding, Rest/binary>>, Stack, Callbacks, ?comments_enabled(Opts)) ->
    maybe_comment(Rest, fun(Resume) -> array(Resume, Stack, Callbacks, Opts) end);
array(Bin, Stack, Callbacks, Opts) when byte_size(Bin) < 4 ->
    {incomplete, fun(Stream) -> array(<<Bin/binary, Stream/binary>>, Stack, Callbacks, Opts) end}.  


value(<<S/?encoding, Rest/binary>>, Stack, Callbacks, Opts) when ?is_whitespace(S) -> 
    value(Rest, Stack, Callbacks, Opts);
value(<<?quote/?encoding, Rest/binary>>, Stack, Callbacks, Opts) ->
    string(Rest, Stack, Callbacks, Opts, []);
value(<<$t/?encoding, Rest/binary>>, Stack, Callbacks, Opts) ->
    tr(Rest, Stack, Callbacks, Opts);
value(<<$f/?encoding, Rest/binary>>, Stack, Callbacks, Opts) ->
    fa(Rest, Stack, Callbacks, Opts);
value(<<$n/?encoding, Rest/binary>>, Stack, Callbacks, Opts) ->
    nu(Rest, Stack, Callbacks, Opts);
value(<<?negative/?encoding, Rest/binary>>, Stack, Callbacks, Opts) ->
    negative(Rest, Stack, Callbacks, Opts, "-");
value(<<?zero/?encoding, Rest/binary>>, Stack, Callbacks, Opts) ->
    zero(Rest, Stack, Callbacks, Opts, "0");
value(<<S/?encoding, Rest/binary>>, Stack, Callbacks, Opts) when ?is_nonzero(S) ->
    integer(Rest, Stack, Callbacks, Opts, [S]);
value(<<?start_object/?encoding, Rest/binary>>, Stack, Callbacks, Opts) ->
    object(Rest, [key|Stack], fold(start_object, Callbacks), Opts);
value(<<?start_array/?encoding, Rest/binary>>, Stack, Callbacks, Opts) ->
    array(Rest, [array|Stack], fold(start_array, Callbacks), Opts);
value(<<?solidus/?encoding, Rest/binary>>, Stack, Callbacks, ?comments_enabled(Opts)) ->
    maybe_comment(Rest, fun(Resume) -> value(Resume, Stack, Callbacks, Opts) end);
value(Bin, Stack, Callbacks, Opts) when byte_size(Bin) < 4 ->
    {incomplete, fun(Stream) -> value(<<Bin/binary, Stream/binary>>, Stack, Callbacks, Opts) end}.


colon(<<S/?encoding, Rest/binary>>, Stack, Callbacks, Opts) when ?is_whitespace(S) ->
    colon(Rest, Stack, Callbacks, Opts);
colon(<<?colon/?encoding, Rest/binary>>, [key|Stack], Callbacks, Opts) ->
    value(Rest, [object|Stack], Callbacks, Opts);
colon(<<?solidus/?encoding, Rest/binary>>, Stack, Callbacks, ?comments_enabled(Opts)) ->
    maybe_comment(Rest, fun(Resume) -> colon(Resume, Stack, Callbacks, Opts) end);
colon(Bin, Stack, Callbacks, Opts) when byte_size(Bin) < 4 ->
    {incomplete, fun(Stream) -> colon(<<Bin/binary, Stream/binary>>, Stack, Callbacks, Opts) end}.


key(<<S/?encoding, Rest/binary>>, Stack, Callbacks, Opts) when ?is_whitespace(S) ->
    key(Rest, Stack, Callbacks, Opts);        
key(<<?quote/?encoding, Rest/binary>>, Stack, Callbacks, Opts) ->
    string(Rest, Stack, Callbacks, Opts, []);
key(<<?solidus/?encoding, Rest/binary>>, Stack, Callbacks, ?comments_enabled(Opts)) ->
    maybe_comment(Rest, fun(Resume) -> key(Resume, Stack, Callbacks, Opts) end);
key(Bin, Stack, Callbacks, Opts) when byte_size(Bin) < 4 ->
    {incomplete, fun(Stream) -> key(<<Bin/binary, Stream/binary>>, Stack, Callbacks, Opts) end}.


%% string has an additional parameter, an accumulator (Acc) used to hold the intermediate
%%   representation of the string being parsed. using a list of integers representing
%%   unicode codepoints is faster than constructing binaries, many of which will be
%%   converted back to lists by the user anyways.

%% the clause starting with Bin is necessary for cases where a stream is broken at a
%%   point where it contains only a partial utf-8 sequence.

string(<<?quote/?encoding, Rest/binary>>, [key|_] = Stack, Callbacks, Opts, Acc) ->
    colon(Rest, Stack, fold({key, lists:reverse(Acc)}, Callbacks), Opts);
string(<<?quote/?encoding, Rest/binary>>, Stack, Callbacks, Opts, Acc) ->
    maybe_done(Rest, Stack, fold({string, lists:reverse(Acc)}, Callbacks), Opts);
string(<<?rsolidus/?encoding, Rest/binary>>, Stack, Callbacks, Opts, Acc) ->
    escape(Rest, Stack, Callbacks, Opts, Acc);   
string(<<S/?encoding, Rest/binary>>, Stack, Callbacks, Opts, Acc) when ?is_noncontrol(S) ->
    string(Rest, Stack, Callbacks, Opts, [S] ++ Acc);   
string(Bin, Stack, Callbacks, Opts, Acc) when byte_size(Bin) < 4 ->
    {incomplete, fun(Stream) -> string(<<Bin/binary, Stream/binary>>, Stack, Callbacks, Opts, Acc) end}.


%% only thing to note here is the additional accumulator passed to escaped_unicode used
%%   to hold the codepoint sequence. unescessary, but nicer than using the string 
%%   accumulator. 

escape(<<$b/?encoding, Rest/binary>>, Stack, Callbacks, Opts, Acc) ->
    string(Rest, Stack, Callbacks, Opts, "\b" ++ Acc);
escape(<<$f/?encoding, Rest/binary>>, Stack, Callbacks, Opts, Acc) ->
    string(Rest, Stack, Callbacks, Opts, "\f" ++ Acc);
escape(<<$n/?encoding, Rest/binary>>, Stack, Callbacks, Opts, Acc) ->
    string(Rest, Stack, Callbacks, Opts, "\n" ++ Acc);
escape(<<$r/?encoding, Rest/binary>>, Stack, Callbacks, Opts, Acc) ->
    string(Rest, Stack, Callbacks, Opts, "\r" ++ Acc);
escape(<<$t/?encoding, Rest/binary>>, Stack, Callbacks, Opts, Acc) ->
    string(Rest, Stack, Callbacks, Opts, "\t" ++ Acc);
escape(<<$u/?encoding, Rest/binary>>, Stack, Callbacks, Opts, Acc) ->
    escaped_unicode(Rest, Stack, Callbacks, Opts, Acc, []);      
escape(<<S/?encoding, Rest/binary>>, Stack, Callbacks, Opts, Acc) 
        when S =:= ?quote; S =:= ?solidus; S =:= ?rsolidus ->
    string(Rest, Stack, Callbacks, Opts, [S] ++ Acc);
escape(Bin, Stack, Callbacks, Opts, Acc) when byte_size(Bin) < 4 ->
    {incomplete, fun(Stream) -> escape(<<Bin/binary, Stream/binary>>, Stack, Callbacks, Opts, Acc) end}.


%% this code is ugly and unfortunate, but so is json's handling of escaped unicode
%%   codepoint sequences. if the ascii option is present, the sequence is converted
%%   to a codepoint and inserted into the string if it represents an ascii value. if 
%%   the codepoint option is present the sequence is converted and inserted as long
%%   as it represents a valid unicode codepoint. this means non-characters 
%%   representable in 16 bits are not converted (the utf16 surrogates and the two
%%   special non-characters). any other option and no conversion is done.

escaped_unicode(<<D/?encoding, Rest/binary>>, 
        Stack, 
        Callbacks, 
        ?escaped_unicode_to_ascii(Opts), 
        String, 
        [C, B, A]) 
            when ?is_hex(D) ->
    case erlang:list_to_integer([A, B, C, D], 16) of
        X when X < 128 ->
            string(Rest, Stack, Callbacks, Opts, [X] ++ String)
        ; _ ->
            string(Rest, Stack, Callbacks, Opts, [D, C, B, A, $u, ?rsolidus] ++ String)
    end;
escaped_unicode(<<D/?encoding, Rest/binary>>, 
        Stack, 
        Callbacks, 
        ?escaped_unicode_to_codepoint(Opts), 
        String, 
        [C, B, A]) 
            when ?is_hex(D) ->
    case erlang:list_to_integer([A, B, C, D], 16) of
        X when X >= 16#dc00, X =< 16#dfff ->
            case check_acc_for_surrogate(String) of
                false ->
                    string(Rest, Stack, Callbacks, Opts, [D, C, B, A, $u, ?rsolidus] ++ String)
                ; {Y, NewString} ->
                    string(Rest, Stack, Callbacks, Opts, [surrogate_to_codepoint(X, Y)] ++ NewString)
            end
        ; X when X < 16#d800; X > 16#dfff, X < 16#fffe ->
            string(Rest, Stack, Callbacks, Opts, [X] ++ String) 
        ; _ ->
            string(Rest, Stack, Callbacks, Opts, [D, C, B, A, $u, ?rsolidus] ++ String)
    end;
escaped_unicode(<<D/?encoding, Rest/binary>>, Stack, Callbacks, Opts, String, [C, B, A]) when ?is_hex(D) ->
    string(Rest, Stack, Callbacks, Opts, [D, C, B, A, $u, ?rsolidus] ++ String);
escaped_unicode(<<S/?encoding, Rest/binary>>, Stack, Callbacks, Opts, String, Acc) when ?is_hex(S) ->
    escaped_unicode(Rest, Stack, Callbacks, Opts, String, [S] ++ Acc);
escaped_unicode(Bin, Stack, Callbacks, Opts, String, Acc) when byte_size(Bin) < 4 ->
    {incomplete, fun(Stream) -> escaped_unicode(<<Bin/binary, Stream/binary>>, Stack, Callbacks, Opts, String, Acc) end}.

%% upon encountering a low pair json/hex encoded value, check to see if there's a high
%%   value already in the accumulator. 

check_acc_for_surrogate([D, C, B, A, $u, ?rsolidus|Rest])
        when ?is_hex(D), ?is_hex(C), ?is_hex(B), ?is_hex(A) ->
    case erlang:list_to_integer([A, B, C, D], 16) of
        X when X >=16#d800, X =< 16#dbff ->
            {X, Rest};
        _ ->
            false
    end;
check_acc_for_surrogate(_) ->
    false.

%% stole this from the unicode spec    

surrogate_to_codepoint(X, Y) ->
    (X - 16#d800) * 16#400 + (Y - 16#dc00) + 16#10000.
        

%% like strings, numbers are collected in an intermediate accumulator before
%%   being emitted to the callback handler. no processing of numbers is done in
%%   process, it's left for the user, though there are convenience functions to
%%   convert them into erlang floats/integers in jsx_utils.erl.

%% TODO: actually write that jsx_utils.erl module mentioned above...

negative(<<$0/?encoding, Rest/binary>>, Stack, Callbacks, Opts, Acc) ->
    zero(Rest, Stack, Callbacks, Opts, "0" ++ Acc);
negative(<<S/?encoding, Rest/binary>>, Stack, Callbacks, Opts, Acc) when ?is_nonzero(S) ->
    integer(Rest, Stack, Callbacks, Opts, [S] ++ Acc);
negative(Bin, Stack, Callbacks, Opts, Acc) when byte_size(Bin) < 4 ->
    {incomplete, fun(Stream) -> negative(<<Bin/binary, Stream/binary>>, Stack, Callbacks, Opts, Acc) end}.


zero(<<?end_object/?encoding, Rest/binary>>, [object|Stack], Callbacks, Opts, Acc) ->
    maybe_done(Rest, Stack, fold(end_object, fold({integer, lists:reverse(Acc)}, Callbacks)), Opts);
zero(<<?end_array/?encoding, Rest/binary>>, [array|Stack], Callbacks, Opts, Acc) ->
    maybe_done(Rest, Stack, fold(end_array, fold({integer, lists:reverse(Acc)}, Callbacks)), Opts);
zero(<<?comma/?encoding, Rest/binary>>, [object|Stack], Callbacks, Opts, Acc) ->
    key(Rest, [key|Stack], fold({integer, lists:reverse(Acc)}, Callbacks), Opts);
zero(<<?comma/?encoding, Rest/binary>>, [array|_] = Stack, Callbacks, Opts, Acc) ->
    value(Rest, Stack, fold({integer, lists:reverse(Acc)}, Callbacks), Opts);
zero(<<?decimalpoint/?encoding, Rest/binary>>, Stack, Callbacks, Opts, Acc) ->
    initial_decimal(Rest, Stack, Callbacks, Opts, [?decimalpoint] ++ Acc);
zero(<<S/?encoding, Rest/binary>>, Stack, Callbacks, Opts, Acc) when ?is_whitespace(S) ->
    maybe_done(Rest, Stack, fold({integer, lists:reverse(Acc)}, Callbacks), Opts);
zero(<<?solidus/?encoding, Rest/binary>>, Stack, Callbacks, ?comments_enabled(Opts), Acc) ->
    maybe_comment(Rest, fun(Resume) -> zero(Resume, Stack, Callbacks, Opts, Acc) end);
zero(<<>>, [], Callbacks, Opts, Acc) ->
    {fold(end_of_stream, fold({integer, lists:reverse(Acc)}, Callbacks)), 
        fun(Stream) -> zero(Stream, [], Callbacks, Opts, Acc) end};
zero(Bin, Stack, Callbacks, Opts, Acc) when byte_size(Bin) < 4 ->
    {incomplete, fun(Stream) -> zero(<<Bin/binary, Stream/binary>>, Stack, Callbacks, Opts, Acc) end}.


integer(<<S/?encoding, Rest/binary>>, Stack, Callbacks, Opts, Acc) when ?is_nonzero(S) ->
    integer(Rest, Stack, Callbacks, Opts, [S] ++ Acc);
integer(<<?end_object/?encoding, Rest/binary>>, [object|Stack], Callbacks, Opts, Acc) ->
    maybe_done(Rest, Stack, fold(end_object, fold({integer, lists:reverse(Acc)}, Callbacks)), Opts);
integer(<<?end_array/?encoding, Rest/binary>>, [array|Stack], Callbacks, Opts, Acc) ->
    maybe_done(Rest, Stack, fold(end_array, fold({integer, lists:reverse(Acc)}, Callbacks)), Opts);
integer(<<?comma/?encoding, Rest/binary>>, [object|Stack], Callbacks, Opts, Acc) ->
    key(Rest, [key|Stack], fold({integer, lists:reverse(Acc)}, Callbacks), Opts);
integer(<<?comma/?encoding, Rest/binary>>, [array|_] = Stack, Callbacks, Opts, Acc) ->
    value(Rest, Stack, fold({integer, lists:reverse(Acc)}, Callbacks), Opts);
integer(<<?decimalpoint/?encoding, Rest/binary>>, Stack, Callbacks, Opts, Acc) ->
    initial_decimal(Rest, Stack, Callbacks, Opts, [?decimalpoint] ++ Acc);
integer(<<?zero/?encoding, Rest/binary>>, Stack, Callbacks, Opts, Acc) ->
    integer(Rest, Stack, Callbacks, Opts, [?zero] ++ Acc);
integer(<<$e/?encoding, Rest/binary>>, Stack, Callbacks, Opts, Acc) ->
    e(Rest, Stack, Callbacks, Opts, "e0." ++ Acc);
integer(<<$E/?encoding, Rest/binary>>, Stack, Callbacks, Opts, Acc) ->
    e(Rest, Stack, Callbacks, Opts, "e0." ++ Acc);
integer(<<S/?encoding, Rest/binary>>, Stack, Callbacks, Opts, Acc) when ?is_whitespace(S) ->
    maybe_done(Rest, Stack, fold({integer, lists:reverse(Acc)}, Callbacks), Opts);
integer(<<?solidus/?encoding, Rest/binary>>, Stack, Callbacks, ?comments_enabled(Opts), Acc) ->
    maybe_comment(Rest, fun(Resume) -> integer(Resume, Stack, Callbacks, Opts, Acc) end);
integer(<<>>, [], Callbacks, Opts, Acc) ->
    {fold(end_of_stream, fold({integer, lists:reverse(Acc)}, Callbacks)), 
        fun(Stream) -> integer(Stream, [], Callbacks, Opts, Acc) end};
integer(Bin, Stack, Callbacks, Opts, Acc) when byte_size(Bin) < 4 ->
    {incomplete, fun(Stream) -> integer(<<Bin/binary, Stream/binary>>, Stack, Callbacks, Opts, Acc) end}.


initial_decimal(<<S/?encoding, Rest/binary>>, Stack, Callbacks, Opts, Acc) when ?is_nonzero(S) ->
    decimal(Rest, Stack, Callbacks, Opts, [S] ++ Acc);
initial_decimal(<<?zero/?encoding, Rest/binary>>, Stack, Callbacks, Opts, Acc) ->
    decimal(Rest, Stack, Callbacks, Opts, [?zero] ++ Acc);
initial_decimal(Bin, Stack, Callbacks, Opts, Acc) when byte_size(Bin) < 4 ->
    {incomplete, fun(Stream) -> initial_decimal(Stream, Stack, Callbacks, Opts, Acc) end}.


decimal(<<S/?encoding, Rest/binary>>, Stack, Callbacks, Opts, Acc) when ?is_nonzero(S) ->
    decimal(Rest, Stack, Callbacks, Opts, [S] ++ Acc);
decimal(<<?end_object/?encoding, Rest/binary>>, [object|Stack], Callbacks, Opts, Acc) ->
    maybe_done(Rest, Stack, fold(end_object, fold({float, lists:reverse(Acc)}, Callbacks)), Opts);
decimal(<<?end_array/?encoding, Rest/binary>>, [array|Stack], Callbacks, Opts, Acc) ->
    maybe_done(Rest, Stack, fold(end_array, fold({float, lists:reverse(Acc)}, Callbacks)), Opts);
decimal(<<?comma/?encoding, Rest/binary>>, [object|Stack], Callbacks, Opts, Acc) ->
    key(Rest, [key|Stack], fold({float, lists:reverse(Acc)}, Callbacks), Opts);
decimal(<<?comma/?encoding, Rest/binary>>, [array|_] = Stack, Callbacks, Opts, Acc) ->
    value(Rest, Stack, fold({float, lists:reverse(Acc)}, Callbacks), Opts);
decimal(<<?zero/?encoding, Rest/binary>>, Stack, Callbacks, Opts, Acc) ->
    decimal(Rest, Stack, Callbacks, Opts, [?zero] ++ Acc);
decimal(<<$e/?encoding, Rest/binary>>, Stack, Callbacks, Opts, Acc) ->
    e(Rest, Stack, Callbacks, Opts, "e" ++ Acc);
decimal(<<$E/?encoding, Rest/binary>>, Stack, Callbacks, Opts, Acc) ->
    e(Rest, Stack, Callbacks, Opts, "e" ++ Acc);
decimal(<<S/?encoding, Rest/binary>>, Stack, Callbacks, Opts, Acc) when ?is_whitespace(S) ->
    maybe_done(Rest, Stack, fold({float, lists:reverse(Acc)}, Callbacks), Opts);
decimal(<<?solidus/?encoding, Rest/binary>>, Stack, Callbacks, ?comments_enabled(Opts), Acc) ->
    maybe_comment(Rest, fun(Resume) -> decimal(Resume, Stack, Callbacks, Opts, Acc) end);
decimal(<<>>, [], Callbacks, Opts, Acc) ->
    {fold(end_of_stream, fold({float, lists:reverse(Acc)}, Callbacks)), 
        fun(Stream) -> decimal(Stream, [], Callbacks, Opts, Acc) end};
decimal(Bin, Stack, Callbacks, Opts, Acc) when byte_size(Bin) < 4 ->
    {incomplete, fun(Stream) -> decimal(<<Bin/binary, Stream/binary>>, Stack, Callbacks, Opts, Acc) end}.


e(<<S/?encoding, Rest/binary>>, Stack, Callbacks, Opts, Acc) when S =:= ?zero; ?is_nonzero(S) ->
    exp(Rest, Stack, Callbacks, Opts, [S] ++ Acc);   
e(<<S/?encoding, Rest/binary>>, Stack, Callbacks, Opts, Acc) when S =:= ?positive; S =:= ?negative ->
    ex(Rest, Stack, Callbacks, Opts, [S] ++ Acc);
e(Bin, Stack, Callbacks, Opts, Acc) when byte_size(Bin) < 4 ->
    {incomplete, fun(Stream) -> e(<<Bin/binary, Stream/binary>>, Stack, Callbacks, Opts, Acc) end}.


ex(<<S/?encoding, Rest/binary>>, Stack, Callbacks, Opts, Acc) when S =:= ?zero; ?is_nonzero(S) ->
    exp(Rest, Stack, Callbacks, Opts, [S] ++ Acc);
ex(Bin, Stack, Callbacks, Opts, Acc) when byte_size(Bin) < 4 ->
    {incomplete, fun(Stream) -> ex(<<Bin/binary, Stream/binary>>, Stack, Callbacks, Opts, Acc) end}.


exp(<<S/?encoding, Rest/binary>>, Stack, Callbacks, Opts, Acc) when ?is_nonzero(S) ->
    exp(Rest, Stack, Callbacks, Opts, [S] ++ Acc);
exp(<<?end_object/?encoding, Rest/binary>>, [object|Stack], Callbacks, Opts, Acc) ->
    maybe_done(Rest, Stack, fold(end_object, fold({float, lists:reverse(Acc)}, Callbacks)), Opts);
exp(<<?end_array/?encoding, Rest/binary>>, [array|Stack], Callbacks, Opts, Acc) ->
    maybe_done(Rest, Stack, fold(end_array, fold({float, lists:reverse(Acc)}, Callbacks)), Opts);
exp(<<?comma/?encoding, Rest/binary>>, [object|Stack], Callbacks, Opts, Acc) ->
    key(Rest, [key|Stack], fold({float, lists:reverse(Acc)}, Callbacks), Opts);
exp(<<?comma/?encoding, Rest/binary>>, [array|_] = Stack, Callbacks, Opts, Acc) ->
    value(Rest, Stack, fold({float, lists:reverse(Acc)}, Callbacks), Opts);
exp(<<?zero/?encoding, Rest/binary>>, Stack, Callbacks, Opts, Acc) ->
    exp(Rest, Stack, Callbacks, Opts, [?zero] ++ Acc);
exp(<<?solidus/?encoding, Rest/binary>>, Stack, Callbacks, ?comments_enabled(Opts), Acc) ->
    maybe_comment(Rest, fun(Resume) -> exp(Resume, Stack, Callbacks, Opts, Acc) end);
exp(<<S/?encoding, Rest/binary>>, Stack, Callbacks, Opts, Acc) when ?is_whitespace(S) ->
    maybe_done(Rest, Stack, fold({float, lists:reverse(Acc)}, Callbacks), Opts);
exp(<<>>, [], Callbacks, Opts, Acc) ->
    {fold(end_of_stream, fold({float, lists:reverse(Acc)}, Callbacks)), 
        fun(Stream) -> exp(Stream, [], Callbacks, Opts, Acc) end};
exp(Bin, Stack, Callbacks, Opts, Acc) when byte_size(Bin) < 4 ->
    {incomplete, fun(Stream) -> exp(<<Bin/binary, Stream/binary>>, Stack, Callbacks, Opts, Acc) end}.


tr(<<$r/?encoding, Rest/binary>>, Stack, Callbacks, Opts) ->
    tru(Rest, Stack, Callbacks, Opts);
tr(Bin, Stack, Callbacks, Opts) when byte_size(Bin) < 4 ->
    {incomplete, fun(Stream) -> tr(<<Bin/binary, Stream/binary>>, Stack, Callbacks, Opts) end}.


tru(<<$u/?encoding, Rest/binary>>, Stack, Callbacks, Opts) ->
    true(Rest, Stack, Callbacks, Opts);
tru(Bin, Stack, Callbacks, Opts) when byte_size(Bin) < 4 ->
    {incomplete, fun(Stream) -> tru(<<Bin/binary, Stream/binary>>, Stack, Callbacks, Opts) end}.


true(<<$e/?encoding, Rest/binary>>, Stack, Callbacks, Opts) ->
    maybe_done(Rest, Stack, fold({literal, true}, Callbacks), Opts);
true(Bin, Stack, Callbacks, Opts) when byte_size(Bin) < 4 ->
    {incomplete, fun(Stream) -> true(<<Bin/binary, Stream/binary>>, Stack, Callbacks, Opts) end}.


fa(<<$a/?encoding, Rest/binary>>, Stack, Callbacks, Opts) ->
    fal(Rest, Stack, Callbacks, Opts);
fa(Bin, Stack, Callbacks, Opts) when byte_size(Bin) < 4 ->
    {incomplete, fun(Stream) -> fa(<<Bin/binary, Stream/binary>>, Stack, Callbacks, Opts) end}.


fal(<<$l/?encoding, Rest/binary>>, Stack, Callbacks, Opts) ->
    fals(Rest, Stack, Callbacks, Opts);
fal(Bin, Stack, Callbacks, Opts) when byte_size(Bin) < 4 ->
    {incomplete, fun(Stream) -> fal(<<Bin/binary, Stream/binary>>, Stack, Callbacks, Opts) end}.


fals(<<$s/?encoding, Rest/binary>>, Stack, Callbacks, Opts) ->
    false(Rest, Stack, Callbacks, Opts);
fals(Bin, Stack, Callbacks, Opts) when byte_size(Bin) < 4 ->
    {incomplete, fun(Stream) -> fals(<<Bin/binary, Stream/binary>>, Stack, Callbacks, Opts) end}.


false(<<$e/?encoding, Rest/binary>>, Stack, Callbacks, Opts) ->
    maybe_done(Rest, Stack, fold({literal, false}, Callbacks), Opts);
false(Bin, Stack, Callbacks, Opts) when byte_size(Bin) < 4 ->
    {incomplete, fun(Stream) -> false(<<Bin/binary, Stream/binary>>, Stack, Callbacks, Opts) end}.


nu(<<$u/?encoding, Rest/binary>>, Stack, Callbacks, Opts) ->
    nul(Rest, Stack, Callbacks, Opts);
nu(Bin, Stack, Callbacks, Opts) when byte_size(Bin) < 4 ->
    {incomplete, fun(Stream) -> nu(<<Bin/binary, Stream/binary>>, Stack, Callbacks, Opts) end}.


nul(<<$l/?encoding, Rest/binary>>, Stack, Callbacks, Opts) ->
    null(Rest, Stack, Callbacks, Opts);
nul(Bin, Stack, Callbacks, Opts) when byte_size(Bin) < 4 ->
    {incomplete, fun(Stream) -> nul(<<Bin/binary, Stream/binary>>, Stack, Callbacks, Opts) end}.


null(<<$l/?encoding, Rest/binary>>, Stack, Callbacks, Opts) ->
    maybe_done(Rest, Stack, fold({literal, null}, Callbacks), Opts);
null(Bin, Stack, Callbacks, Opts) when byte_size(Bin) < 4 ->
    {incomplete, fun(Stream) -> null(<<Bin/binary, Stream/binary>>, Stack, Callbacks, Opts) end}.    


%% comments are c style, /* blah blah */ and are STRONGLY discouraged. any unicode
%%   character is valid in a comment, except, obviously the */ sequence which ends
%%   the comment. they're implemented as a closure called when the comment ends that
%%   returns execution to the point where the comment began. comments are not 
%%   recorded in any way, simply parsed.    

maybe_comment(<<?star/?encoding, Rest/binary>>, Resume) ->
    comment(Rest, Resume);
maybe_comment(Bin, Resume) when byte_size(Bin) < 4 ->
    {incomplete, fun(Stream) -> maybe_comment(<<Bin/binary, Stream/binary>>, Resume) end}.


comment(<<?star/?encoding, Rest/binary>>, Resume) ->
    maybe_comment_done(Rest, Resume);
comment(<<_/?encoding, Rest/binary>>, Resume) ->
    comment(Rest, Resume);
comment(Bin, Resume) when byte_size(Bin) < 4 ->
    {incomplete, fun(Stream) -> comment(<<Bin/binary, Stream/binary>>, Resume) end}.


maybe_comment_done(<<?solidus/?encoding, Rest/binary>>, Resume) ->
    Resume(Rest);
maybe_comment_done(Bin, Resume) when byte_size(Bin) < 4 ->
    {incomplete, fun(Stream) -> maybe_comment_done(<<Bin/binary, Stream/binary>>, Resume) end}.