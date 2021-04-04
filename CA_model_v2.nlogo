;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;; Setup and main loop ;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
extensions [rnd]
turtles-own [ppf prod_plan endowment u_params degree trade? learning_rate clone? mutant?]
links-own [deal strength]
globals [trades_done]

to setup
  clear-all
  set trades_done 0
  crt agents [
    setxy random-xcor random-ycor
    set trade? true
    set degree min list (agents - 1) random 10
    set ppf n-values goods [ 1 + random 9 ]
    set prod_plan n-values goods [ 1 ]
    set endowment n-values goods [ 100 ]
    set u_params softmax n-values goods [ 1 + random 9 ]
    set learning_rate 0.25
    set clone? false
    set mutant? false
  ]
  ask turtles [
    create-links-to n-of degree other turtles [
      set strength 1
      set deal choose_from_plural both-ends random_deals
      set color blue
    ]
  ]
;  ask turtles [
;    create-links-to other turtles [ ; this could me tunable... less connected vs more connected
;      set strength 1 ; this could be where it's tuned
;      set deal random_vect goods 10
;      set color scale-color blue strength 5 30
;      ]
;    ]
  layout-circle turtles max-pxcor * 0.55
  reset-ticks
end

to go
  if not allow_trade? [ ask turtles [set trade? false ]]
  ask turtles with [ trade? ] [
    produce
    trade_with find_partner
    consume
  ]
  ask turtles with [ not trade? ] [
    produce
    consume
    solo_update
  ]
  ask turtles [
    update_trade?
    set prod_plan all_positive prod_plan
  ]
  ask links [
    set color scale-color blue strength 5 30
  ]
  tick
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;; Trade functions ;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to-report mutually_beneficial? [ partners dealio ]
  ;; option 1
;  report reduce and [ask partners [ evaluate_deal dealio > 0 ]]
  ;; option 2
  let out true
  foreach partners [
    ask self [
      set out out and evaluate_deal dealio
    ]
  ]
  report out
end

to-report choose_from_plural [ partners options ]
  ask partners [
    set options filter [ o -> evaluate_deal o > 0 ] options
  ]
  if length options = 0 [report choose_from_plural partners cross_over_mutation random_deal random_deal]
  report options
end


to trade_with [ partner ]
  if partner = nobody [ stop ]
  let option1 [deal] of out-link-to partner
  let chosen_deal option1
  let mutate? 1 <= random ticks  ;; mutate more at the start, less as time goes on.
  if mutate? [
    let option2 [deal] of one-of other links
    let options cross_over_mutation option1 option2
    set chosen_deal choose_from options
  ]
  ;; decide if partner likes the deal
  ;; maybe there should be a negotiation that sets the deal?
  undertake chosen_deal
  update chosen_deal
  ask partner [
    undertake negate chosen_deal
    update negate chosen_deal
  ]
  ask out-link-to partner [
    set strength strength + 1
    set deal chosen_deal
  ]
end

to undertake [ dealio ]
  if length dealio != length endowment [ print dealio ]
  if self = end2 [ set dealio negate dealio ]
  set endowment (map [ [en dl] -> en + dl ] endowment dealio)
end

to-report evaluate_deal [ dealio ]
  ; report change in utility if dealio is undertaken
  let U utility
  undertake dealio
  let out utility - U
  undertake negate dealio
  report out
end

to-report random_deal
  report n-values goods [ round random-normal 0 5 ]
end

to-report random_deals
  report cross_over_mutation random_deal random_deal
end

to-report choose_from [ options ]
  ; loop through a list of possible trades
  let dUs map evaluate_deal options
  let bestU max dUs
  if bestU < 0 [ ; ensure deal is utility enhancing
   set options cross_over_mutation random_deal random_deal
   report choose_from options
  ]
  let best filter [o -> evaluate_deal o = bestU] options
  report one-of best ; in case two are equivalent, give a random option
end

to-report find_partner
  let possible_partners other turtles with [link-neighbor? myself]
  ; look at link-neighbors ready to trade, with a bias towards agents I've successfully traded with before.
  report rnd:weighted-one-of possible_partners with [trade?] [[strength] of in-link-from myself]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;; Strategy functions ;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to update_towards  [ vect ]
  set prod_plan (map [ [p v] -> max list 1 p + v * learning_rate] prod_plan vect)
end

to update [ dealio ]
  ; start simple. Make this function more complicated later...
  update_towards dealio
end

to solo_update_new
  let new_plan point_mutation_add prod_plan ; I should rename mutate_trade
  let u1 try_plan new_plan
  let u2 try_plan prod_plan
  if u1 > u2 [
    set prod_plan new_plan
  ]
end

to solo_update
  ; try a random mutation, see if it increases utility, then
  ; adopt the mutation if it results in greater utility.
  let delta prod_plan
  hatch 1 [
    set clone? true
    set mutant? true
    mutate_prod
    set delta vect_diff delta prod_plan ; diff of prod_plan and initial prod_plan
    produce
  ]
  hatch 1 [
    set clone? true
    produce
  ]
  let u_change mean [ utility ] of turtles-here with [ clone? and mutant? ]
  let u_base mean [ utility ] of turtles-here with [ clone? and not mutant? ]
  if u_change > u_base [
   set prod_plan vect_add prod_plan delta
  ]
  ask turtles with [clone?] [die]
end

to mutate_prod
  let delta point_mutation_add n-values goods [ 0 ]
  set prod_plan all_positive (map [ [prod d ] -> max list 1 prod + d ] prod_plan delta)
end

to-report try_plan [ plan ]
  hatch 1 [
    set clone? true
    set prod_plan plan
    produce
  ]
  let out [utility] of turtles-here with [ clone? ]
  ask turtles-here with [ clone? ] [ die ]
  report out
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;; Procedures ;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to update_trade?
  ; if min endowment isn't high enough, don't trade
  let M min [endowment] of self
  set trade? M > 25
end

to produce
;  let sumP sum prod_plan
;  let production (map [ prod -> prod / sumP ] prod_plan)
;  let production soft_max prod_plan
  let production (map [ [plan poss] -> plan * poss ] softmax prod_plan ppf)
  set endowment (map [ [en pr] -> en + pr ] endowment production)
end

to consume
  ; eat up some of the resources
end


;;;;;;;;;;;;;;;;;;;;
;;;;; Reporters ;;;;
;;;;;;;;;;;;;;;;;;;;

to-report utility
  report reduce + (map [ [ n u ] -> n ^ u ] endowment u_params)
end

to-report specialization
  let top max softmax prod_plan
  let base 1 / goods
  report top / base
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;; Convenience Functions ;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; add a constant amount to each element of a vector
; so the smallest element is +1
to-report all_positive [ vect ]
  let diff abs min vect
  if min vect < 0 [
    set vect map [a -> a + diff + 1] vect
  ]
  report vect
end

to-report softmax [ lst ]
  let S sum lst
  report map [ l -> l / S ] lst
end

to-report exponential_smooth [ alpha past present ]
  report alpha * present + (1 - alpha) * past
end

to-report vect_diff [ vect1 vect2 ]
  if length vect1 != length vect2 [report vect1]
  report (map [[a b] -> a - b] vect1 vect2)
end

to-report vect_add [ vect1 vect2 ]
  if length vect1 != length vect2 [report vect1]
  report (map [[a1 a2] -> a1 + a2] vect1 vect2)
end

to-report negate [ vect ]
  report (map [ v -> 0 - v ] vect )
end

to-report random_sign
  ifelse random 2 < 1 [
    report -1
  ][
    report 1
  ]
end

to-report random_vect [ len max_num ]
  report n-values len [ random_sign * random max_num ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;; Genetic Functions ;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to-report point_mutation_add [ vect ]
  let m random length vect
  let x (item m vect) + 1
  report replace-item m vect x
end

to-report point_mutation_shrink [ vect ]
  let m random length vect
  let x (item m vect) / 2
  report replace-item m vect x
end

to-report cross_over_mutation [ vect1 vect2 ]
  let m max list 1 random length vect1
  ; assume vects are the same length
  let a1 sublist vect1 0 m
  let a2 sublist vect1 m length vect1
  let b1 sublist vect2 0 m
  let b2 sublist vect2 m length vect2
  let vect3 sentence a1 b2
  let vect4 sentence b1 a2
  report (list vect1 vect2 vect3 vect4)
end
@#$#@#$#@
GRAPHICS-WINDOW
263
33
700
471
-1
-1
13.0
1
10
1
1
1
0
1
1
1
-16
16
-16
16
0
0
1
ticks
30.0

BUTTON
23
31
96
64
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
110
32
253
65
go 100 * goods
repeat (100 * goods) [ go ]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
22
78
194
111
agents
agents
2
50
50.0
1
1
NIL
HORIZONTAL

SLIDER
22
121
194
154
goods
goods
2
10
2.0
1
1
NIL
HORIZONTAL

MONITOR
709
32
849
77
ppf 0
[ppf] of turtle 0
0
1
11

MONITOR
995
31
1135
76
ppf 1
[ppf] of turtle 1
0
1
11

MONITOR
709
79
991
124
plan 0
[map [pp -> round pp] prod_plan] of turtle 0
0
1
11

MONITOR
995
79
1277
124
plan 1
[map [pp -> round pp] prod_plan] of turtle 1
0
1
11

MONITOR
709
125
991
170
endmt 0
[map [en -> round en] endowment] of turtle 0
1
1
11

MONITOR
995
125
1277
170
endmt 1
[map [en -> round en] endowment] of turtle 1
1
1
11

MONITOR
708
171
765
216
u 0
[utility] of turtle 0
1
1
11

MONITOR
995
173
1052
218
u 1
[utility] of turtle 1
1
1
11

PLOT
1295
407
1571
557
Distribution of link strength
NIL
NIL
0.0
35.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" "histogram [strength] of links"

PLOT
1295
245
1571
395
Utility distribution
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" "histogram [utility] of turtles"

PLOT
711
244
1278
394
Utility
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Mean utility" 1.0 0 -16777216 true "" "plot mean [utility] of turtles"
"Turtle 0" 1.0 0 -13840069 true "" "plot [utility] of turtle 0"
"Turtle 1" 1.0 0 -2674135 true "" "plot [utility] of turtle 1"

MONITOR
858
31
991
76
NIL
[trade?] of turtle 0
17
1
11

MONITOR
1143
31
1276
76
NIL
[trade?] of turtle 1
17
1
11

SWITCH
23
161
169
194
allow_trade?
allow_trade?
0
1
-1000

MONITOR
712
570
801
615
mean utility
mean [utility] of turtles
2
1
11

MONITOR
870
570
1012
615
mean specialization
mean [specialization] of turtles
2
1
11

PLOT
714
409
1279
559
Specialization
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Mean specialization" 1.0 0 -16777216 true "" "plot mean [specialization] of turtles"
"Turtle 0" 1.0 0 -13840069 true "" "plot [specialization] of turtle 0"
"Turtle 1" 1.0 0 -2674135 true "" "plot [specialization] of turtle 1"

MONITOR
711
624
797
669
sd of utility
standard-deviation [utility] of turtles
2
1
11

MONITOR
596
576
676
621
max utility
max [utility] of turtles
2
1
11

MONITOR
595
631
672
676
min utility
min [utility] of turtles
2
1
11

MONITOR
873
635
968
680
NIL
trades_done
17
1
11

BUTTON
25
220
188
253
go for a while
repeat 100 [ go ]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SWITCH
21
277
163
310
production?
production?
1
1
-1000

BUTTON
25
370
115
403
go once
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.1.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="experiment" repetitions="5" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>mean [utility] of turtles</metric>
    <metric>mean [specialization] of turtles</metric>
    <enumeratedValueSet variable="allow_trade?">
      <value value="false"/>
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="agents">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="goods">
      <value value="2"/>
      <value value="3"/>
      <value value="5"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="attempts" repetitions="30" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>mean [utility] of turtles</metric>
    <metric>mean [specialization] of turtles</metric>
    <enumeratedValueSet variable="allow_trade?">
      <value value="false"/>
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="agents">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="goods">
      <value value="2"/>
      <value value="3"/>
      <value value="5"/>
      <value value="10"/>
    </enumeratedValueSet>
    <steppedValueSet variable="trade_attempts" first="1" step="2" last="10"/>
  </experiment>
  <experiment name="experiment2" repetitions="20" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="500"/>
    <metric>mean [utility] of turtles</metric>
    <metric>mean [specialization] of turtles</metric>
    <enumeratedValueSet variable="allow_trade?">
      <value value="false"/>
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="agents">
      <value value="20"/>
      <value value="40"/>
      <value value="80"/>
      <value value="160"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="goods">
      <value value="2"/>
      <value value="3"/>
      <value value="5"/>
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="trade_attempts">
      <value value="1"/>
      <value value="2"/>
      <value value="4"/>
      <value value="8"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="simple" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="500"/>
    <metric>mean [utility] of turtles</metric>
    <metric>mean [specialization] of turtles</metric>
    <enumeratedValueSet variable="agents">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="allow_trade?">
      <value value="true"/>
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="goods">
      <value value="2"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
