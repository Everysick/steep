class Steep::Parser

rule

target: type_METHOD method_type { result = val[1] }
      | type_INTERFACES interfaces { result = val[1] }
      | type_ANNOTATION annotation { result = val[1] }

method_type: params block_opt ARROW type
               { result = Types::Interface::Method.new(type_params: [], params: val[0], block: val[1], return_type: val[3]) }
           | LT type_param_seq GT params block_opt ARROW type
               { result = Types::Interface::Method.new(type_params: val[1], params: val[3], block: val[4], return_type: val[6]) }

params: { result = Types::Interface::Params.empty }
      | LPAREN params0 RPAREN { result = val[1] }
      | type { result = Types::Interface::Params.empty.with(required: [val[0]]) }

params0: required_param { result = Types::Interface::Params.empty.with(required: [val[0]]) }
       | required_param COMMA params0 { result = val[2].with(required: [val[0]] + val[2].required) }
       | params1 { result = val[0] }

params1: optional_param { result = Types::Interface::Params.empty.with(optional: [val[0]]) }
       | optional_param COMMA params1 { result = val[2].with(optional: [val[0]] + val[2].optional) }
       | params2 { result = val[0] }

params2: rest_param { result = Types::Interface::Params.empty.with(rest: val[0]) }
       | rest_param COMMA params3 { result = val[2].with(rest: val[0]) }
       | params3 { result = val[0] }

params3: required_keyword { result = Types::Interface::Params.empty.with(required_keywords: val[0]) }
       | optional_keyword { result = Types::Interface::Params.empty.with(optional_keywords: val[0]) }
       | required_keyword COMMA params3 { result = val[2].with(required_keywords: val[2].required_keywords.merge(val[0])) }
       | optional_keyword COMMA params3 { result = val[2].with(optional_keywords: val[2].optional_keywords.merge(val[0])) }
       | params4 { result = val[0] }

params4: { result = Types::Interface::Params.empty }
       | STAR2 type { result = Types::Interface::Params.empty.with(rest_keywords: val[1]) }

required_param: type { result = val[0] }
optional_param: QUESTION type { result = val[1] }
rest_param: STAR type { result = val[1] }
required_keyword: keyword COLON type { result = { val[0] => val[2] } }
optional_keyword: QUESTION keyword COLON type { result = { val[1] => val[3] } }

block_opt: { result = nil }
         | LBRACE RBRACE { result = Types::Interface::Block.new(params: Types::Interface::Params.empty.with(rest: Types::Any.new),
                                                                return_type: Types::Any.new) }
         | LBRACE block_params ARROW type RBRACE { result = Types::Interface::Block.new(params: val[1], return_type: val[3]) }

block_params: LPAREN block_params0 RPAREN { result = val[1] }
            | { result = Types::Interface::Params.empty.with(rest: Types::Any.new) }

block_params0: required_param { result = Types::Interface::Params.empty.with(required: [val[0]]) }
             | required_param COMMA block_params0 { result = val[2].with(required: [val[0]] + val[2].required) }
             | block_params1 { result = val[0] }

block_params1: optional_param { result = Types::Interface::Params.empty.with(optional: [val[0]]) }
            | optional_param COMMA block_params1 { result = val[2].with(optional: [val[0]] + val[2].optional) }
            | block_params2 { result = val[0] }

block_params2: { result = Types::Interface::Params.empty }
             | rest_param { result = Types::Interface::Params.empty.with(rest: val[0]) }

type: IDENT { result = Types::Name.new(name: val[0], params: []) }
    | IDENT LT type_seq GT { result = Types::Name.new(name: val[0], params: val[2]) }
    | ANY { result = Types::Any.new }
    | TVAR { result = Types::Var.new(name: val[0]) }

type_seq: type { result = [val[0]] }
        | type COMMA type_seq { result = [val[0]] + val[2] }

keyword: IDENT { result = val[0] }

interfaces: { result = [] }
          | interface interfaces { result = [val[0]] + val[1] }

interface: INTERFACE interface_name type_params method_decls END { result = Types::Interface.new(name: val[1], params: val[2], methods: val[3]) }

interface_name: IDENT { result = val[0] }

type_params: { result = [] }
          | LT type_param_seq GT { result = val[1] }

type_param_seq: TVAR { result = [val[0]] }
           | TVAR COMMA type_param_seq { result = [val[0]] + val[2] }

method_decls: { result = {} }
            | method_decl method_decls { result = val[1].merge(val[0]) }

method_decl: DEF method_name COLON method_type { result = { val[1] => val[3] } }

method_name: IDENT { result = val[0] }
           | INTERFACE { result = :interface }
           | END { result = :end }
           | PLUS { result = :+ }

annotation: AT_TYPE subject COLON type { result = Annotation::VarType.new(var: val[1], type: val[3]) }
          | AT_TYPE subject COLON method_type { result = Annotation::MethodType.new(method: val[1], type: val[3]) }
          | AT_TYPE { raise "Invalid type annotation" }

subject: IDENT { result = val[0] }

end

---- inner

require "strscan"

attr_reader :input

def initialize(type, input)
  super()
  @type = type
  @input = StringScanner.new(input)
end

def self.parse_method(input)
  new(:METHOD, input).do_parse
end

def self.parse_interfaces(input)
  new(:INTERFACES, input).do_parse
end

def self.parse_annotation_opt(input)
  new(:ANNOTATION, input).do_parse
rescue
  nil
end

def next_token
  if @type
    type = @type
    @type = nil
    return [:"type_#{type}", nil]
  end

  case
  when input.scan(/\s+/)
    next_token
  when input.scan(/#.*/)
    next_token
  when input.eos?
    [false, false]
  when input.scan(/->/)
    [:ARROW, nil]
  when input.scan(/\?/)
    [:QUESTION, nil]
  when input.scan(/\(/)
    [:LPAREN, nil]
  when input.scan(/\)/)
    [:RPAREN, nil]
  when input.scan(/{/)
    [:LBRACE, nil]
  when input.scan(/}/)
    [:RBRACE, nil]
  when input.scan(/,/)
    [:COMMA, nil]
  when input.scan(/:/)
    [:COLON, nil]
  when input.scan(/\*\*/)
    [:STAR2, nil]
  when input.scan(/\*/)
    [:STAR, nil]
  when input.scan(/\+/)
    [:PLUS, nil]
  when input.scan(/</)
    [:LT, nil]
  when input.scan(/>/)
    [:GT, nil]
  when input.scan(/any/)
    [:ANY, nil]
  when input.scan(/interface/)
    [:INTERFACE, nil]
  when input.scan(/end/)
    [:END, nil]
  when input.scan(/def/)
    [:DEF, nil]
  when input.scan(/@type/)
    [:AT_TYPE, nil]
  when input.scan(/'\w+/)
    [:TVAR, input.matched.gsub(/\A'/, '').to_sym]
  when input.scan(/\w+/)
    [:IDENT, input.matched.to_sym]
  end
end