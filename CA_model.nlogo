extensions [rnd]
turtles-own [ppf prod_plan endowment u_params trade? strategies]
links-own [trade_history strength]
globals [trade_attempts trades_done]

; random-seed 12345  ; comment this out when running experiments

to setup
  clear-all
  set trade_attempts 5
  let G range goods
  crt agents [
    setxy random-xcor random-ycor
    set trade? true
    set ppf n-values goods [ 1 + random 9 ]
    set prod_plan n-values goods [ 1 ]
    set endowment n-values goods [ 25 ]
  ;  set u_params n-values goods [ 1 + random 9 ]
 ;   let sumU sum u_params
;    set u_params (map [u -> u / sumU] u_params)
    set u_params softmax n-values goods [ 1 + random 9 ]
    max_u_autarky
  ]
  ask turtles [
    create-links-with other turtles [
      set strength 1
      set trade_history (list "buyerGives" "sellerGives" "Qb" "Qs")
      set color scale-color blue strength 5 20
    ]
  ]
  reset-ticks
end

to go
  ask turtles with [trade?] [
    produce
    trade trade_attempts ; each turtle gets a finite number of attempts
    consume
  ]
  ask turtles with [not trade?] [
    produce
    consume
  ]
  ask turtles [update_trade?]
  ask links [ set color scale-color blue strength 5 20 ]
  tick
end

;;;;;;;;;;;;;;;;;;;;
;;;; Procedures ;;;;
;;;;;;;;;;;;;;;;;;;;

to max_u_autarky  ; fix to account for ppf slope
  let m min u_params
  set prod_plan (map [ u -> u / m ] u_params)
end

to produce
  let sumP sum prod_plan
  let production (map [ prod -> prod / sumP ] prod_plan)
  set production (map [ [plan poss] -> plan * poss ] production ppf)
  set endowment (map [ [en pr] -> en + pr ] endowment production)
end

to consume
  ; eat up some of the resources
end

to trade [attempts]
  if attempts < 1 [
;    print "no trade"
    stop ]
  if allow_trade? [
;    print "attempting trade"
    let partner rnd:weighted-one-of other turtles with [trade?] [[strength] of link-with myself]
    if partner != nobody [ trade_with partner attempts]
  ]
end

to trade_with [ partner attempts ]
  let buyerGives random goods
  let sellerGives random goods
  while [ buyerGives = sellerGives ][ set sellerGives random goods ]
  let Qb (item buyerGives [ppf] of partner)
  let Qs (item sellerGives [ppf] of self)
  while [
    (Qb > (item buyerGives [endowment] of partner)) or
    (Qs > (item sellerGives [endowment] of self))
  ][
    set Qb Qb / 2
    set Qs Qs / 2
  ]
  let ratio Qb / Qs
  let buyertradeoff [tradeoff buyerGives SellerGives] of self
  let sellertradeoff [tradeoff sellerGives buyerGives] of partner
  let good? false
  ; make sure the trade makes sense and enhances utility
  if (ratio < buyertradeoff) and (ratio > sellertradeoff) [
    set good? (evaluate_trade buyerGives sellerGives Qb Qs) and
    ([evaluate_trade sellerGives buyerGives Qs Qb] of partner)
  ]
  if good? [
    undertake_trade buyerGives sellerGives Qb Qs
    update_trade?
    ask partner [
      undertake_trade sellerGives buyerGives Qs Qb
      update_trade?
    ]
    ask link-with partner [
      set strength strength + 1
      set trade_history lput (list buyerGives sellerGives Qb Qs) trade_history
    ]
;    print "trade made"
    set trades_done trades_done + 1
  ]
  ; I was getting lower utility with trade enabled until I added this line
  ; I suspect I was getting trades to "mess up" production plans relative to
  ; max U in autarky
  ; but not enough trades to benefit from increased overall productivity.
  ; The attempts parameter keeps it from looking for infinite possible trades
  ; just in case I get a lone turtle looking for a good trade but with nobody to
  ; trade with
  if not good? [ trade (attempts - 1)] ; this might slow things down... if the trade isn't good, try a different one.
end

to-report evaluate_trade [give get q_give q_get]
  let base_u [utility] of self
  let out false
  set endowment replace-item give endowment (item give endowment - q_give)
  set endowment replace-item get endowment (item get endowment + q_get)
  if [utility] of self >= base_u [set out true]
  set endowment replace-item give endowment (item give endowment + q_give)
  set endowment replace-item get endowment (item get endowment - q_get)
  report out
end

to undertake_trade [give get q_give q_get]
  set endowment replace-item give endowment (item give endowment - q_give)
  set endowment replace-item get endowment (item get endowment + q_get)
  set prod_plan replace-item give prod_plan (item give prod_plan + 1)
end

to update_trade?
  ; if min endowment isn't high enough, don't trade
  let M min [endowment] of self
  set trade? M > 25
end

to update_strategies [ cross_over mutation ]
  ;;; run genetic algorithm on a set of strategies a turtle might have.
  ;;
  let best_score 0
  let best_strategy null_strategy
  foreach strategies [ the_strategy ->
    let score 0
    apply_strategy the_strategy
    let score utility
    if score >= best_score [
      set best_score score
      set best_strategy the_strategy
    ]
  ]
end

;;;;;;;;;;;;;;;;;;;
;;;; Reporters ;;;;
;;;;;;;;;;;;;;;;;;;

to-report null_strategy
  report n-values strategy_space [0]
end

to-report create_strategies [ num_strategies ]
  report n-values num_strategies random_strategy
end

to-report apply_strategy [ external_inputs ]
  ; allow some input to be mapped to some output
  ; inputs:
  ;   - my endowment
  ;   - partner traits
  ;   - time, space, neighbors
  ; outputs:
  ;   - proposed trade
end

to-report random_strategy

end

to-report tradeoff [good1 good2]
  let g1 item good1 [ppf] of myself
  let g2 item good2 [ppf] of myself
  report g1 / g2
end

to-report utility
;  if min (list endowment) < 0 [report 0]
;  report max list 0 reduce + (map [ [n u] -> n ^ u ] endowment u_params)
  report reduce + (map [ [ n u ] -> n ^ u ] endowment u_params)
end

to-report softmax [ lst ]
  let S sum lst
  report map [ l -> l / S ] lst
end

to-report specialization
  let top max softmax prod_plan
  let base 1 / goods
  report top / base
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
18.0
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
10.0
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
while [(goods * agents * 10) > trades_done] [\ngo\n]
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
