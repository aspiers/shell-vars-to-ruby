The awarded answer should include Ruby code that:

- parses properly output(list) of shell variables 

- can include shell code to simplify reading, but preferable
  should be something small like piping through awk/sed 

- all variables must be read, including arrays and un-exported variables 

- multiline variables have to be read properly, not stoping on single quotes in values -> ' 

- functions, aliases and other non variables should be ignored
  (although separate hashes of functions/aliases would be nice too!)

- variables definitions inside of functions should be ignored 

- array variables from both BASH and ZSH should be supported

reference implementation:
  https://github.com/mpapis/tf/blob/master/lib/tf/environment.rb

reference test:
  https://github.com/mpapis/tf/blob/master/test/unit/environment_test.rb