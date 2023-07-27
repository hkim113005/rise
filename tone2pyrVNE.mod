:Tone to Pyramidal Cells AMPA+NMDA with local Ca2+ pool

NEURON {
	POINT_PROCESS tone2pyrVNE
	USEION ca READ eca	
	NONSPECIFIC_CURRENT inmda, iampa
	RANGE initW
	RANGE Cdur_nmda, AlphaTmax_nmda, Beta_nmda, Erev_nmda, gbar_nmda, W_nmda, on_nmda, g_nmda
	RANGE Cdur_ampa, AlphaTmax_ampa, Beta_ampa, Erev_ampa, gbar_ampa, W, on_ampa, g_ampa
	RANGE eca, ICa, P0, fCa, tauCa, iCatotal
	RANGE Cainf, pooldiam, z
	RANGE lambda1, lambda2, threshold1, threshold2
	RANGE fmax, fmin, Wmax, Wmin, maxChange, normW, scaleW
	RANGE pregid,postgid
}

UNITS {
	(mV) = (millivolt)
        (nA) = (nanoamp)
	(uS) = (microsiemens)
	FARADAY = 96485 (coul)

	pi = 3.141592 (1)
}

PARAMETER {
	Cdur_nmda = 16.7650 (ms)
	AlphaTmax_nmda = .2659 (/ms)
	Beta_nmda = 0.008 (/ms)
	Erev_nmda = 0 (mV)
	gbar_nmda = .5e-3 (uS)

	Cdur_ampa = 1.4210 (ms)
	AlphaTmax_ampa = 3.8142 (/ms)
	Beta_ampa = 0.1429 (/ms)
	Erev_ampa = 0 (mV)
	gbar_ampa = 1e-3 (uS)
 
	eca = 120

	Cainf = 50e-6 (mM)
	pooldiam =  1.8172 (micrometer)
	z = 2

	tauCa = 50 (ms)
	P0 = .015
	fCa = .024
	
	NEstart1 = 39500
	NEstop1 = 40000	
	NEstart2 = 35900
	NEstop2 = 36000		

	NE_t1 = 1 : 0.8 : 0.8tyyyyy77777777;l
	NE_t2 = 0.9 : 0.9 : 1
	NE_S = 1.5 : 2 : 1.5 : 1.1	
	Beta1 = 0.001  (/ms) : 1/decay time for neuromodulators
	Beta2 = 0.0001  (/ms)
	
	initW = 6 : 5: 5 : 5 : 4 : 3 : 4 : 5 : 4

	lambda1 = 6 : 15 : 20 : 30 : 20 : 20 : 13
	lambda2 = .04 : .03
	threshold1 = 0.40 : 0.35 : 0.45 : 0.5 : 0.3 (uM)
	threshold2 = 0.53 : 0.55 : 0.60 : 0.55 : 0.55 : 0.6 : 0.4 : 0.45 (uM)

	fmax = 3.5 : 4 : 3.5
	fmin = .8

}

ASSIGNED {
	v (mV)

	inmda (nA)
	g_nmda (uS)
	on_nmda
	W_nmda

	iampa (nA)
	g_ampa (uS)
	on_ampa
	W

	t0 (ms)

	ICa (mA)
	Afactor	(mM/ms/nA)
	iCatotal (mA)

	dW_ampa
	Wmax
	Wmin
	maxChange
	normW
	scaleW
	
	pregid
	postgid
}

STATE { r_nmda r_ampa capoolcon }

INITIAL {
	on_nmda = 0
	r_nmda = 0
	W_nmda = initW

	on_ampa = 0
	r_ampa = 0
	W = initW

	t0 = -1

	Wmax = fmax*initW
	Wmin = fmin*initW
	maxChange = (Wmax-Wmin)/10
	dW_ampa = 0

	capoolcon = Cainf
	Afactor	= 1/(z*FARADAY*4/3*pi*(pooldiam/2)^3)*(1e6)
}

BREAKPOINT {
	SOLVE release METHOD cnexp
}

DERIVATIVE release {
	if (t0>0) {
		if (t-t0 < Cdur_nmda) {
			on_nmda = 1
		} else {
			on_nmda = 0
		}
		if (t-t0 < Cdur_ampa) {
			on_ampa = 1
		} else {
			on_ampa = 0
		}
	}
	r_nmda' = AlphaTmax_nmda*on_nmda*(1-r_nmda)-Beta_nmda*r_nmda
	r_ampa' = AlphaTmax_ampa*on_ampa*(1-r_ampa)-Beta_ampa*r_ampa

	dW_ampa = eta(capoolcon)*(lambda1*omega(capoolcon, threshold1, threshold2)-lambda2*W)*dt

	: Limit for extreme large weight changes
	if (fabs(dW_ampa) > maxChange) {
		if (dW_ampa < 0) {
			dW_ampa = -1*maxChange
		} else {
			dW_ampa = maxChange
		}
	}

	:Normalize the weight change
	normW = (W-Wmin)/(Wmax-Wmin)
	if (dW_ampa < 0) {
		scaleW = sqrt(fabs(normW))
	} else {
		scaleW = sqrt(fabs(1.0-normW))
	}

	W = W + dW_ampa*scaleW
	
	:Weight value limits
	if (W > Wmax) { 
		W = Wmax
	} else if (W < Wmin) {
 		W = Wmin
	}

	g_nmda = gbar_nmda*r_nmda*NEn(NEstart1,NEstop1)*NE2(NEstart2,NEstop2)
	inmda = W_nmda*g_nmda*(v - Erev_nmda)*sfunc(v)

	g_ampa = gbar_ampa*r_ampa
	iampa = W*g_ampa*(v - Erev_ampa)

	ICa = P0*g_nmda*(v - eca)*sfunc(v)
	capoolcon'= -fCa*Afactor*ICa + (Cainf-capoolcon)/tauCa
}

NET_RECEIVE(dummy_weight) {
	t0 = t
}

:::::::::::: FUNCTIONs and PROCEDUREs ::::::::::::

FUNCTION sfunc (v (mV)) {
	UNITSOFF
	sfunc = 1/(1+0.33*exp(-0.06*v))
	UNITSON
}

FUNCTION eta(Cani (mM)) {
	LOCAL taulearn, P1, P2, P4, Cacon
	P1 = 0.1
	P2 = P1*1e-4
	P4 = 1
	Cacon = Cani*1e3
	taulearn = P1/(P2+Cacon*Cacon*Cacon)+P4
	eta = 1/taulearn*0.001
}

FUNCTION omega(Cani (mM), threshold1 (uM), threshold2 (uM)) {
	LOCAL r, mid, Cacon
	Cacon = Cani*1e3
	r = (threshold2-threshold1)/2
	mid = (threshold1+threshold2)/2
	if (Cacon <= threshold1) { omega = 0}
	else if (Cacon >= threshold2) {	omega = 1/(1+50*exp(-50*(Cacon-threshold2)))}
	else {omega = -sqrt(r*r-(Cacon-mid)*(Cacon-mid))}
}
FUNCTION NEn(NEstart1 (ms), NEstop1 (ms)) {
	LOCAL NEtemp1, NEtemp2, NEtemp3, NEtemp4, NEtemp5, NEtemp6, NEtemp7, NEtemp8, NEtemp9, NEtemp10, NEtemp11, NEtemp12, NEtemp13, NEtemp14, NEtemp15, NEtemp16, NEtemp17, NEtemp18,s
	NEtemp1 = NEstart1+4000
	NEtemp2 = NEtemp1+4000
	NEtemp3 = NEtemp2+4000
	NEtemp4 = NEtemp3+4000
	NEtemp5 = NEtemp4+4000
	NEtemp6 = NEtemp5+4000
	NEtemp7 = NEtemp6+4000
	NEtemp8 = NEtemp7+4000
	NEtemp9 = NEtemp8+4000
	NEtemp10 = NEtemp9+4000
	NEtemp11 = NEtemp10+4000
	NEtemp12 = NEtemp11+4000
	NEtemp13 = NEtemp12+4000
	NEtemp14 = NEtemp13+4000
	NEtemp15 = NEtemp14 + 4000 + 100000     : 100sec Gap
	NEtemp16 = NEtemp15 + 4000 
	NEtemp17 = NEtemp16 + 4000
	NEtemp18 = NEtemp17 + 4000

	if (t <= NEstart1) { NEn = 1.0}
	else if (t >= NEstart1 && t <= NEstop1) {NEn = NE_t1}					: 2nd tone in early conditioning (EC)
		else if (t > NEstop1 && t < NEtemp1) {NEn = 1.0 + (NE_t1-1)*exp(-Beta1*(t-NEstop1))}  		: Basal level
	else if (t >= NEtemp1 && t <= NEtemp1+500) {NEn = NE_t1}					: 3rd tone EC
		else if (t > NEtemp1+500 && t < NEtemp2) {NEn = 1.0 + (NE_t1-1)*exp(-Beta1*(t-NEstop1))}  	: Basal level
	else if (t >= NEtemp2 && t <= NEtemp2+500) {NEn = NE_t1}					: 4th tone EC
		else if (t > NEtemp2+500 && t < NEtemp3) {NEn = 1.0 + (NE_t1-1)*exp(-Beta1*(t-(NEtemp2+500)))}  	: Basal level	
	else if (t >= NEtemp3 && t <= NEtemp3+500) {NEn = NE_t1}					: 5th tone EC
		else if (t > NEtemp3+500 && t < NEtemp4) {NEn = 1.0 + (NE_t1-1)*exp(-Beta1*(t-(NEtemp3+500)))}  	: Basal level
	else if (t >= NEtemp4 && t <= NEtemp4+500) {NEn = NE_t1}					: 6th tone EC
		else if (t > NEtemp4+500 && t < NEtemp5) {NEn = 1.0 + (NE_t1-1)*exp(-Beta1*(t-(NEtemp4+500)))}  		: Basal level
	else if (t >= NEtemp5 && t <= NEtemp5+500) {NEn = NE_t1}					: 7th tone EC
		else if (t > NEtemp5+500 && t < NEtemp6) {NEn = 1.0 + (NE_t1-1)*exp(-Beta1*(t-(NEtemp5+500)))}  	: Basal level
	else if (t >= NEtemp6 && t <= NEtemp6+500) {NEn = NE_t1}					: 8th tone EC
		else if (t > NEtemp6+500 && t < NEtemp7) {NEn = 1.0 + (NE_t1-1)*exp(-Beta1*(t-(NEtemp6+500)))}  	: Basal level
	
	else if (t >= NEtemp7 && t <= NEtemp7+500) {NEn = NE_t2}					: 9th tone	- Second Step late cond (LC)
		else if (t > NEtemp7+500 && t < NEtemp8) {NEn = 1.0 + (NE_t2-1)*exp(-Beta2*(t-(NEtemp7+500)))}  		: Basal level
	else if (t >= NEtemp8 && t <= NEtemp8+500) {NEn = NE_t2}					: 10th tone  LC
		else if (t > NEtemp8+500 && t < NEtemp9) {NEn = 1.0 + (NE_t2-1)*exp(-Beta2*(t-(NEtemp8+500)))}		: Basal level	
	else if (t >= NEtemp9 && t <= NEtemp9+500) {NEn = NE_t2}					: 11th tone  LC 
		else if (t > NEtemp9+500 && t < NEtemp10) {NEn = 1.0 + (NE_t2-1)*exp(-Beta2*(t-(NEtemp9+500)))}  	: Basal level	
	else if (t >= NEtemp10 && t <= NEtemp10+500) {NEn = NE_t2}					: 12th tone  LC
		else if (t > NEtemp10+500 && t < NEtemp11) {NEn = 1.0 + (NE_t2-1)*exp(-Beta2*(t-(NEtemp10+500)))}  	: Basal level
	else if (t >= NEtemp11 && t <= NEtemp11+500) {NEn = NE_t2}					: 13th tone  LC
		else if (t > NEtemp11+500 && t < NEtemp12) {NEn = 1.0 + (NE_t2-1)*exp(-Beta2*(t-(NEtemp11+500)))}  	: Basal level
	else if (t >= NEtemp12 && t <= NEtemp12+500) {NEn = NE_t2}					: 14th tone  LC
		else if (t > NEtemp12+500 && t < NEtemp13) {NEn = 1.0 + (NE_t2-1)*exp(-Beta2*(t-(NEtemp12+500)))}  	: Basal level
	else if (t >= NEtemp13 && t <= NEtemp13+500) {NEn = NE_t2}					: 15th tone  LC
		else if (t > NEtemp13+500 && t < NEtemp14) {NEn = 1.0 + (NE_t2-1)*exp(-Beta2*(t-(NEtemp13+500)))}  	: Basal level
	else if (t >= NEtemp14 && t <= NEtemp14+500) {NEn = NE_t2}					: 16th tone  LC
		else if (t > NEtemp14+500 && t < NEtemp15) {NEn = 1.0 + (NE_t2-1)*exp(-Beta2*(t-(NEtemp14+500)))}  	: Basal level
	
	else if (t >= NEtemp15 && t <= NEtemp15+500) {NEn = NE_t2}					: 1st tone in Early Extinction EE
		else if (t > NEtemp15+500 && t < NEtemp16) {NEn = 1.0 + (NE_t2-1)*exp(-Beta2*(t-(NEtemp15+500)))} 		: Basal level
	else if (t >= NEtemp16 && t <= NEtemp16+500) {NEn = NE_t2}					: 2nd tone EE
		else if (t > NEtemp16+500 && t < NEtemp17) {NEn = 1.0 + (NE_t2-1)*exp(-Beta2*(t-(NEtemp16+500)))}  	: Basal level
	else if (t >= NEtemp17 && t <= NEtemp17+500) {NEn = NE_t2}					: 3rd tone EE
		else if (t > NEtemp17+500 && t < NEtemp18) {NEn = 1.0 + (NE_t2-1)*exp(-Beta2*(t-(NEtemp17+500)))}  	: Basal level	
	else if (t >= NEtemp18 && t <= NEtemp18+500) {NEn = NE_t2}					: 4th tone EE	
		else  {	NEn = 1.0}
}
FUNCTION NE2(NEstart2 (ms), NEstop2 (ms)) {
	LOCAL NE2temp1, NE2temp2, NE2temp3, NE2temp4, NE2temp5, NE2temp6, NE2temp7, NE2temp8, NE2temp9, NE2temp10, NE2temp11, NE2temp12, NE2temp13, NE2temp14, NE2temp15, NE2temp16,s
	NE2temp1 = NEstart2 + 4000
	NE2temp2 = NE2temp1 + 4000
	NE2temp3 = NE2temp2 + 4000
	NE2temp4 = NE2temp3 + 4000
	NE2temp5 = NE2temp4 + 4000
	NE2temp6 = NE2temp5 + 4000
	NE2temp7 = NE2temp6 + 4000
	NE2temp8 = NE2temp7 + 4000
	NE2temp9 = NE2temp8 + 4000
	NE2temp10 = NE2temp9 + 4000
	NE2temp11 = NE2temp10 + 4000
	NE2temp12 = NE2temp11 + 4000 
	NE2temp13 = NE2temp12 + 4000
	NE2temp14 = NE2temp13 + 4000
	NE2temp15 = NE2temp14 + 4000
	
	if (t <= NEstart2) { NE2 = 1.0}
	else if (t >= NEstart2 && t <= NEstop2) {NE2 = NE_S }					: 1st shock
		else if (t > NEstop2 && t < NE2temp1) {NE2 = 1.0 + (NE_S-1)*exp(-Beta2*(t-(NEstop2+500)))} 
	else if (t >= NE2temp1 && t <= NE2temp1+100) {NE2=NE_S}					: 2nd shock
		else if (t > NE2temp1+100 && t < NE2temp2) {NE2 = 1.0 + (NE_S-1)*exp(-Beta2*(t-(NE2temp1+100)))}   				 
	else if (t >= NE2temp2 && t <= NE2temp2+100) {NE2=NE_S}					: 3rd shock
		else if (t > NE2temp2+100 && t < NE2temp3) {NE2 = 1.0 + (NE_S-1)*exp(-Beta2*(t-(NE2temp2+100)))}  				 
	else if (t >= NE2temp3 && t <= NE2temp3+100) {NE2=NE_S}					: 4th shock
		else if (t > NE2temp3+100 && t < NE2temp4) {NE2 = 1.0 + (NE_S-1)*exp(-Beta2*(t-(NE2temp3+100)))}  				 
	else if (t >= NE2temp4 && t <= NE2temp4+100) {NE2=NE_S}					: 5th shock
		else if (t > NE2temp4+100 && t < NE2temp5) {NE2 = 1.0 + (NE_S-1)*exp(-Beta2*(t-(NE2temp4+100)))}  				 
	else if (t >= NE2temp5 && t <= NE2temp5+100) {NE2=NE_S}					: 6th shock
		else if (t > NE2temp5+100 && t < NE2temp6) {NE2 = 1.0 + (NE_S-1)*exp(-Beta2*(t-(NE2temp5+100)))} 				 
	else if (t >= NE2temp6 && t <= NE2temp6+100) {NE2=NE_S}					: 7th shock
		else if (t > NE2temp6+100 && t < NE2temp7) {NE2 = 1.0 + (NE_S-1)*exp(-Beta2*(t-(NE2temp6+100)))}  				 
	else if (t >= NE2temp7 && t <= NE2temp7+100) {NE2=NE_S}					: 8th shock
		else if (t > NE2temp7+100 && t < NE2temp8) {NE2 = 1.0 + (NE_S-1)*exp(-Beta2*(t-(NE2temp7+100)))}  				    
	else if (t >= NE2temp8 && t <= NE2temp8+100) {NE2=NE_S }					: 9th shock
		else if (t > NE2temp8+100 && t < NE2temp9) {NE2 = 1.0 + (NE_S-1)*exp(-Beta2*(t-(NE2temp8+100)))}  				    
	else if (t >= NE2temp9 && t <= NE2temp9+100) {NE2=NE_S }					: 10th shock
		else if (t > NE2temp9+100 && t < NE2temp10) {NE2 = 1.0 + (NE_S-1)*exp(-Beta2*(t-(NE2temp9+100)))}  				    
	else if (t >= NE2temp10 && t <= NE2temp10+100) {NE2=NE_S}					: 11th shock
		else if (t > NE2temp10+100 && t < NE2temp11) {NE2 = 1.0 + (NE_S-1)*exp(-Beta2*(t-(NE2temp10+100)))}  				 
	else if (t >= NE2temp11 && t <= NE2temp11+100) {NE2=NE_S }					: 12th shock
		else if (t > NE2temp11+100 && t < NE2temp12) {NE2 = 1.0 + (NE_S-1)*exp(-Beta2*(t-(NE2temp11+100)))}  				 
	else if (t >= NE2temp12 && t <= NE2temp12+100) {NE2=NE_S}					: 13th shock
		else if (t > NE2temp12+100 && t < NE2temp13) {NE2 = 1.0 + (NE_S-1)*exp(-Beta2*(t-(NE2temp12+100)))} 				 
	else if (t >= NE2temp13 && t <= NE2temp13+100) {NE2=NE_S }					: 14th shock
		else if (t > NE2temp13+100 && t < NE2temp14) {NE2 = 1.0 + (NE_S-1)*exp(-Beta2*(t-(NE2temp13+100)))}   				 
	else if (t >= NE2temp14 && t <= NE2temp14+100) {NE2=NE_S}					: 15th shock
		else if (t > NE2temp14+100 && t < NE2temp15) {NE2 = 1.0 + (NE_S-1)*exp(-Beta2*(t-(NE2temp14+100)))}  				 
	else if (t >= NE2temp15 && t <= NE2temp15+100) {NE2=NE_S}					: 16th shock
		else  {	NE2 = 1.0}
}