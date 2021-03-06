#pragma rtGlobals=1		// Use modern global access method.

#include "In2_GeneralProcedures"	//we need functions from this file

Menu "USAXS"
	"---"
	"Size Distribution", IN2R_Sizes()
end


//this is Sizes procedure.
//this is list of procedures:
//	Data input is done by
	//IN2R_SelectAndCopyData()			//Procedure which loads data and sets work folder
	//IN2R_SetupFittingParameters()		//sets up the graph and panel to control the Sizes
	//
//	Calculate G[][]		done for spheres,
	//procedures:		GenerateShapeFunction()
	//				CalculateSphereFormFactor(FRwave,Qw,radius)	
	//				CalculateSphereFFPoints(Qvalue,radius)
	//				NormalizationFactorSphere(radius)
	//
	//	Units handling:
	//	drho^2 is in 10^20 cm-4, G matrix calculations need to be in cm, so volume of 
	//	particles is in cm3 (10-24 A3) and width of the sectors is in cm.
	//
	//
	//
//	Calculate H matrix	done,
	//procedures:		MakeHmatrix()
	//
//	CalculateBVector()	done, single procedure
	//makes new B vector and calculates values from G, Int and errors
	//	
//	CalculateDMatrix()
	//calculates D matrix from G[][] and errors
	//
//	CalculateAvalue()
	//calculates the A[][]= d[][] + a * H[][]
	//
//	FindOptimumAvalue(Evalue)	
	//does the fitting itself, call with precision (e~0.1 or so)
	// procedures : 	CalculateCvalue()	
	//				
	//this function does the whole Sizes procedure
	//List of waves, vectors, and matrixes
	//	works in root:Packages:Sizes
	//	Intensity	[M]
	//	Error	[M]
	//	Q_vec	[M]
	//	R_distribution	[N]		contains distribution of radia for particles, defines number of points in solution
	//	G_matrix		[M] [N]	Shape matrix, for now spheres
	//	H_matrix		[N] [N]	Constraint matrix, here done for second derivative
	//	B_vector		[N]			
	//	A_matrix	[N][N]
	//	D_matrix	[M][N]
	//	Evalue					precision, for now hardwired to 0.1
	//	Difference		chi squared sum of the difference value between the fit and measured intensity		
//units used:
//	All units internally are in A - Radius and Q ([A^-1]). 
//
//
//****************************************
// Main Evaluation procedure:
//****************************************
Function IN2R_Sizes()

	IN2G_UniversalFolderScan("root:USAXS:", 5, "IN2G_CheckTheFolderName()")  //here we fix the folder names/sample names in wave notes if necessary
			
	IN2R_SelectAndCopyData()			//Procedure which loads data and sets work folder
												//creates keyword-list with parameters of the process
	IN2R_SetupFittingParameters()			//here we create distribution of radia for sizes
end

//*********************************************************************************************
//*********************************************************************************************

Function IN2R_SizesFitting(ctrlName) : ButtonControl			//this function is called by button from the panel
	String ctrlName

	IN2R_FinishSetupOfRegParam()	//finishes the setup of parametes for Sizes

	SVAR SlitSmearedData
	if (cmpstr(SlitSmearedData, "Yes")==0)	//if we are working with slit smeared data
		IN2R_ExtendQVecForSmearing()	//here we extend them by slitLength
	endif		
		
	IN2R_GenerateGmatrix()			//this function creates G_matrix for given shape of particles

	if (cmpstr(SlitSmearedData, "Yes")==0)	//if we are working with slit smeared data
		IN2R_SmearGMatrix()			//here we smear the Columns in the G matrix
		IN2R_ShrinkGMatrixAfterSmearing()	//here we cut the G matrix back in length
	endif		

	IN2R_MakeHmatrix()				//creates H matrix
	
	IN2R_CalculateBVector()			//creates B vector
	
	IN2R_CalculateDMatrix()			//creates D matrix
	
	variable Evalue=0.1				//may not be needed in the future
	
	IN2R_FindOptimumAvalue(Evalue)	//does the  fitting for given e value, for now set here to a value 0.1
	
	IN2R_FinishGraph()				//fishies the graph to proper shape
	
	//note, the longest time takes D matrix and then G matrix. The others are fast.
end	

//*********************************************************************************************
//*********************************************************************************************

Function IN2R_SelectAndCopyData()		//this function selects data to be used and copies them with proper names to Sizes folder

	string FldrWithData					//this is where the original data are
		
	Prompt FldrWithData, "select folder with data", popup, IN2G_FindFolderWithWaveTypes("root:", 10, "*DSM*", 1)+";"+IN2G_FindFolderWithWaveTypes("root:", 10, "*SMR*", 1)		//this needs to be cutomized to give only folders with useful data

	DoPrompt "Select Folder with data", FldrWithData		//get user to tell us where the data are
	if (V_Flag)
		abort "User canceled"
	endif
	
	IN2G_AppendAnyText("\r************************************\r")
	IN2G_AppendAnyText("Started Size distribution fitting procedure")
	IN2G_AppendAnyText("Data:  \t"+FldrWithData)

	SetDataFolder $FldrWithData							//go to the data folder
	
	if (!DataFolderExists("root:Packages:Sizes"))		//create packages:Sizes folder, if it does not exist
		NewDataFolder/O root:Packages
		NewDataFolder/O root:Packages:Sizes
	endif
	
	string IntName, Qname, Ename						//strings with wave names 
	
	Prompt IntName, "Wave with Intensity data", popup, WaveList("*SMR*",";","" )+";"+WaveList("*DSM*",";","" )			//IN2G_ConvertDataDirToList(DataFolderDir(2))
	Prompt Qname, "Wave with Q data", popup, WaveList("*SMR*",";","" )+";"+WaveList("*DSM*",";","" )					//IN2G_ConvertDataDirToList(DataFolderDir(2))
	Prompt Ename, "Wave with Error data", popup, WaveList("*SMR*",";","" )+";"+WaveList("*DSM*",";","" )				//IN2G_ConvertDataDirToList(DataFolderDir(2))
	
	DoPrompt "Select data to use in Sizes", IntName, Qname, Ename		//get user input on wave names
	if (V_Flag)
		abort "User canceled"
	endif
	
	Duplicate/O $Intname, root:Packages:Sizes:IntensityOriginal			//here goes original Intensity
	Duplicate/O $Intname, root:Packages:Sizes:Intensity					//and its second copy, for fixing
	Duplicate/O $Qname, root:Packages:Sizes:Q_vec					//Q vector 
	Duplicate/O $Qname, root:Packages:Sizes:Q_vecOriginal				//second copy of the Q vector
	Duplicate/O $Ename, root:Packages:Sizes:Errors						//errors
	Duplicate/O $Ename, root:Packages:Sizes:ErrorsOriginal
	
	string fldrName1=GetDataFolder(1)											//get where the data were
	SetDataFolder root:Packages:Sizes									//go into the packages/Sizes folder

	string/G fldrName=fldrName1												//record parameters there
	String/G SizesParameters
	SizesParameters=ReplaceStringByKey("RegDataFrom", SizesParameters, fldrName,"=")
	SizesParameters=ReplaceStringByKey("RegIntensity", SizesParameters, Intname,"=")
	SizesParameters=ReplaceStringByKey("RegQvector", SizesParameters, Qname,"=")
	SizesParameters=ReplaceStringByKey("RegError", SizesParameters, Ename,"=")
end

//*********************************************************************************************
//*********************************************************************************************

Function IN2R_SetupFittingParameters()			//dialog for radius wave creation, simple linear binning now.

	NVAR/Z numOfPoints
	if (!NVAR_Exists(numOfPoints))
		variable/G numOfPoints=40
		NVAR numOfPoints
	endif

	NVAR/Z AspectRatio
	if (!NVAR_Exists(AspectRatio))
		variable/G AspectRatio=1
		NVAR AspectRatio
	endif

	NVAR/Z SlitLength
	if (!NVAR_Exists(SlitLength))
		variable/G SlitLength=NumberByKey("SlitLength", Note(Intensity), "=")
		NVAR SlitLength
	endif

	NVAR/Z Rmin
	if (!NVAR_Exists(Rmin))
		variable/G Rmin=25
		NVAR Rmin
	endif
	
	NVAR/Z Rmax
	if (!NVAR_Exists(Rmax))
		variable/G Rmax=1000
		NVAR Rmax
	endif
	
	NVAR/Z Bckg
	if (!NVAR_Exists(Bckg))
		variable/G Bckg=0.1
		NVAR Bckg
	endif
	
	NVAR/Z ScatteringContrast
	if (!NVAR_Exists(ScatteringContrast))
		variable/G ScatteringContrast=1
		NVAR ScatteringContrast
	endif
	
	NVAR/Z Dmin
	if (!NVAR_Exists(Dmin))
		variable/G Dmin=25
		NVAR Dmin
	endif

	NVAR/Z Dmax
	if (!NVAR_Exists(Dmax))
		variable/G Dmax=1000
		NVAR Dmax
	endif

	NVAR/Z ErrorsMultiplier
	if (!NVAR_Exists(ErrorsMultiplier))
		variable/G ErrorsMultiplier=1
		NVAR ErrorsMultiplier
	endif

	SVAR/Z LogDist
	if (!SVAR_Exists(LogDist))
		string/G LogDist="yes"
		SVAR LogDist
	endif

	SVAR/Z ShapeType
	if (!SVAR_Exists(ShapeType))
		string/G ShapeType="Spheroid"	
		SVAR ShapeType
	endif

	SVAR/Z SlitSmearedData
	if (!SVAR_Exists(SlitSmearedData))
		string/G SlitSmearedData="no"	
		SVAR SlitSmearedData
	endif

	Wave IntensityOriginal
	Wave ErrorsOriginal

	Duplicate/O IntensityOriginal BackgroundWave			//this background wave is to hel user ot subtract background
	Duplicate/O IntensityOriginal DeletePointsMaskWave		//this wave is used to delete points by using this as amark wave and seting points to 
	Duplicate/O ErrorsOriginal DeletePointsMaskErrorWave		//delete to NaN. Then Intensity is at appropriate time mulitplied by this wave (and divided)
														//to set points to delete to NaNs
	DeletePointsMaskWave=7								//this is symbol number used...
	BackgroundWave=Bckg
	
	Execute("IN2R_SizesInputGraph()")				//this creates the graph
	Execute("IN2R_SizesInputPanel()")				//this panel
	IN2G_AutoAlignGraphAndPanel()						//this aligns them together
end

//*********************************************************************************************
//*********************************************************************************************

Function IN2R_FinishSetupOfRegParam()			//Finish the preparation for parameters selected in the panel

	Wave DeletePointsMaskWave
	Wave IntensityOriginal
	Wave Intensity
	Wave Q_vec
	Wave Q_vecOriginal
	Wave Errors
	Wave ErrorsOriginal
	SVAR ShapeType
	SVAR SizesParameters						
	SVAR LogDist
	SVAR SlitSmearedData
	NVAR Bckg
	NVAR numOfPoints
	NVAR Dmin
	NVAR Dmax
	NVAR Rmin
	NVAR Rmax
	NVAR AspectRatio
	NVAR ScatteringContrast
	NVAR ErrorsMultiplier

	Duplicate/O IntensityOriginal, Intensity						//here we return in the original data, which will be trimmed next
	Duplicate/O Q_vecOriginal, Q_vec
	Duplicate/O ErrorsOriginal, Errors
	
	Errors=ErrorsMultiplier*ErrorsOriginal						//mulitply the erros by user selected multiplier
	
	Intensity=Intensity*(DeletePointsMaskWave/7)				//since DeletePointsMaskWave contains NaNs for points which we want to delete
															//at htis moment we set these points in intensity to NaNs
	Intensity=Intensity-Bckg							//subtract background from Intensity
	
	if ( ((strlen(CsrWave(A))!=0) && (strlen(CsrWave(B))!=0) ) && (pcsr (A)!=pcsr (B)) )	//this should make sure, that both cursors are in the graph and not on the same point
		IN2R_TrimData(Intensity,Q_vec,Errors)					//this trims the data with cursors
	endif
	
	IN2G_RemoveNaNsFromWaves(Intensity,Q_vec,Errors)		//this should remove NaNs from the important waves
	
	Rmax=Dmax/2										//create radia from user input
	Rmin=Dmin/2
	
	make /D/O/N=(numOfPoints) R_distribution, temp		//this part creates the distribution of radia
	if (cmpstr(LogDist,"no")==0)							//linear binninig
		R_distribution=Rmin+p*((Rmax-Rmin)/(numOfPoints-1))
	else													//log binnning (default)
		temp=log(Rmin)+p*((log(Rmax)-log(Rmin))/(numOfPoints-1))
		R_distribution=10^temp
	endif
	Killwaves temp										//kill this wave, not needed anymore

	Duplicate/O R_distribution D_distribution				//and create the Diameter distribution wave
	D_distribution*=2										//and put diameters there
	
	SizesParameters=ReplaceStringByKey("RegNumPoints", SizesParameters, num2str(numOfPoints),"=")
	SizesParameters=ReplaceStringByKey("RegRmin", SizesParameters, num2str(Rmin),"=")
	SizesParameters=ReplaceStringByKey("RegRmax", SizesParameters, num2str(Rmax),"=")
	SizesParameters=ReplaceStringByKey("RegErrorsMultiplier", SizesParameters, num2str(ErrorsMultiplier),"=")
	SizesParameters=ReplaceStringByKey("RegLogRBinning", SizesParameters,LogDist,"=")
	SizesParameters=ReplaceStringByKey("RegParticleShape", SizesParameters, ShapeType,"=")
	SizesParameters=ReplaceStringByKey("RegBackground", SizesParameters, num2str(Bckg),"=")
	SizesParameters=ReplaceStringByKey("RegAspectRatio", SizesParameters, num2str(AspectRatio),"=")
	SizesParameters=ReplaceStringByKey("RegScatteringContrast", SizesParameters, num2str(ScatteringContrast),"=")
	SizesParameters=ReplaceStringByKey("RegSlitSmearedData", SizesParameters, SlitSmearedData,"=")
end

//*********************************************************************************************
//*********************************************************************************************

Function IN2R_TrimData(wave1, wave2, wave3) 				//this is local trimming procedure
	Wave wave1, wave2, wave3
	
	variable AP=pcsr (A)
	variable BP=pcsr (B)
	
	deletePoints 0, AP, wave1, wave2, wave3
	variable newLength=numpnts(wave1)
	deletePoints (BP-AP+1), (newLength),  wave1, wave2, wave3
End

//*********************************************************************************************
//*********************************************************************************************

Function IN2R_GenerateGmatrix()								//here we create G matrix, this takes most time 
	//this function creates G  matrix, Q_vec is q vector distribution, R_distribution is radia distribution
	Wave Q_vec
	Wave R_distribution
	SVAR ShapeType
	NVAR AspectRatio
	
	variable M=numpnts(Q_vec)
	variable N=numpnts(R_distribution)
	Make/D/O/N=(M,N) G_matrix							//note that all matrices and vectors (waves) need to be double precission!!!
	Make/D/O/N=(M) TempWave
	variable i=0, currentR
	
	For (i=0;i<N;i+=1)										//calculate the G matrix in columns!!!
		currentR=R_distribution[i]							//this is current radius
		if (cmpstr(ShapeType,"Spheroid")==0)
			if ((AspectRatio<=1.05)&&(AspectRatio>=0.95))
				IN2R_CalculateSphereFormFactor(TempWave,Q_vec,currentR)	//here we calculate one column of data
				TempWave*=IN2R_SphereVolume(currentR)					//multiply by volume of sphere
				TempWave*=IN2R_BinWidthInRadia(i)							//multiply by the width of radia bin (delta r)
				G_matrix[][i]=TempWave[p]								//and here put it into G wave
			else
				IN2R_CalcSpheroidFormFactor(TempWave,Q_vec,currentR,AspectRatio)	//here we calculate one column of data
				TempWave*=IN2R_SpheroidVolume(currentR,AspectRatio)					//multiply by volume of sphere
				TempWave*=IN2R_BinWidthInRadia(i)							//multiply by the width of radia bin (delta r)
				G_matrix[][i]=TempWave[p]								//and here put it into G wave
			endif
		else
			Abort "other shapes not coded yet, G_matrix not created"
		endif
	endfor
	//here we have corrections for units and contrast
	G_matrix*=1e-24			//this is conversion for Volume of particles from A to cm
	NVAR ScatteringContrast
	G_matrix*=ScatteringContrast*1e20		//this multiplyies by scattering contrast
//	G_matrix*=1e-8			//this fixes the width of the bin from A to cm 
	
end
//*********************************************************************************************
//*********************************************************************************************

Function IN2R_BinWidthInRadia(i)			//calculates the width in radia by taking half distance to point before and after
	variable i								//returns number in A
	Wave R_distribution
	variable width
	variable Imax=numpnts(R_distribution)
	
	if (i==0)
		width=R_distribution[1]-R_distribution[0]
	elseif (i==Imax-1)
		width=R_distribution[i]-R_distribution[i-1]
	else
		width=((R_distribution[i]-R_distribution[i-1])/2)+((R_distribution[i+1]-R_distribution[i])/2)
	endif
	return width
end


//**************************************************************************************************************
//**************************************************************************************************************

Function IN2R_CalculateSphereFormFactor(FRwave,Qw,radius)	
	Wave Qw,FRwave					//returns column (FRwave) for column of Qw and radius
	Variable radius	
	
	FRwave=IN2R_CalculateSphereFFPoints(Qw[p],radius)		//calculates the formula 
	FRwave*=FRwave											//second power of the value
end


Function IN2R_CalculateSphereFFPoints(Qvalue,radius)
	variable Qvalue, radius										//does the math for Sphere Form factor function
	variable QR=Qvalue*radius

	return (3/(QR*QR*QR))*(sin(QR)-(QR*cos(QR)))
end

Function IN2R_SphereVolume(radius)							//returns the sphere...
	variable radius
	return ((4/3)*pi*radius*radius*radius)
end
//*********************************************************************************************
//*********************************************************************************************
Function IN2R_CalcSpheroidFormFactor(FRwave,Qw,radius,AR)	
	Wave Qw,FRwave					//returns column (FRwave) for column of Qw and radius
	Variable radius, AR	
	
	FRwave=IN2R_CalcIntgSpheroidFFPoints(Qw[p],radius,AR)	//calculates the formula 
	FRwave*=FRwave											//second power of the value
end


Function IN2R_CalcIntgSpheroidFFPoints(Qvalue,radius,AR)		//we have to integrate from 0 to 1 over cos(th)
	variable Qvalue, radius	, AR
	
	Make/O/N=50 IntgWave
	SetScale/P x 0,0.02,"", IntgWave
	IntgWave=IN2R_CalcSpheroidFFPoints(Qvalue,radius,AR, x)	//this 
	variable result= area(IntgWave, 0,1)
	KillWaves IntgWave
	return result
end

Function IN2R_CalcSpheroidFFPoints(Qvalue,radius,AR,CosTh)
	variable Qvalue, radius	, AR, CosTh							//does the math for Spheroid Form factor function
	variable QR=Qvalue*radius*sqrt(1+(((AR*AR)-1)*CosTh*CosTh))

	return (3/(QR*QR*QR))*(sin(QR)-(QR*cos(QR)))
end

Function IN2R_SpheroidVolume(radius,AspectRatio)							//returns the spheroid volume...
	variable radius, AspectRatio
	return ((4/3)*pi*radius*radius*radius*AspectRatio)				//what is the volume of spheroid?
end


//*********************************************************************************************
//*********************************************************************************************

Function IN2R_MakeHmatrix()									//makes the H matrix
	Wave R_distribution
	
	variable numOfPoints=numpnts(R_Distribution), i=0, j=0

	Make/D/O/N=(numOfPoints,numOfPoints) H_matrix			//make the matrix
	H_matrix=0												//zero the matrix
	
	For(i=2;i<numOfPoints-2;i+=1)								//this fills with 1 -4 6 -4 1 most of the matrix
		For(j=0;j<numOfPoints;j+=1)
			if(j==i-2)
				H_matrix[i][j]=1
			endif
			if(j==i-1)
				H_matrix[i][j]=-4
			endif
			if(j==i)
				H_matrix[i][j]=6
			endif
			if(j==i+1)
				H_matrix[i][j]=-4
			endif
			if(j==i+2)
				H_matrix[i][j]=1
			endif
		endfor
	endfor
															//now we need to fill in the first and last parts
	H_matrix[0][0]=1											//beginning of the H matrix
	H_matrix[0][1]=-2
	H_matrix[0][2]=1
	H_matrix[1][0]=-2
	H_matrix[1][1]=5
	H_matrix[1][2]=-4
	H_matrix[1][3]=1

	H_matrix[numOfPoints-2][numOfPoints-4]=1					//end of the H matrix
	H_matrix[numOfPoints-2][numOfPoints-3]=-4
	H_matrix[numOfPoints-2][numOfPoints-2]=5
	H_matrix[numOfPoints-2][numOfPoints-1]=-2
	H_matrix[numOfPoints-1][numOfPoints-3]=1
	H_matrix[numOfPoints-1][numOfPoints-2]=-2
	H_matrix[numOfPoints-1][numOfPoints-1]=1
end

//*********************************************************************************************
//*********************************************************************************************

Function IN2R_CalculateBVector()								//makes new B vector and calculates values from G, Int and errors
	
	Wave G_matrix
	Wave Intensity
	Wave Errors
	
	variable M=DimSize(G_matrix, 0)							//rows, i.e, measured points number
	variable N=DimSize(G_matrix, 1)							//columns, i.e., bins in distribution
	variable i=0, j=0
	Make/D/O/N=(N) B_vector									//points = bins in size dist.
	B_vector=0
	for (i=0;i<N;i+=1)					
		For (j=0;j<M;j+=1)
			B_vector[i]+=((G_matrix[j][i]*Intensity[j])/(Errors[j]*Errors[j]))
		endfor
	endfor
end


//*********************************************************************************************
//*********************************************************************************************

Function IN2R_CalculateDMatrix()								//makes new D matrix and calculates values from G, Int and errors
	
	Wave G_matrix
	Wave Errors
	
	variable N=DimSize(G_matrix, 1)							//rows, i.e, measured points number
	variable M=DimSize(G_matrix, 0)							//columns, i.e., bins in distribution
	variable i=0, j=0, k=0
	Make/D/O/N=(N,N) D_matrix	
	Duplicate Errors, Errors2
	Errors2=Errors^2
			
	D_matrix=0
	
	for (i=0;i<N;i+=1)					
		for (k=0;k<N;k+=1)					
			For (j=0;j<M;j+=1)
				D_matrix[i][k]+=(G_matrix[j][i]*G_matrix[j][k])/(Errors2[j])
			endfor
		endfor
	endfor
	KillWaves Errors2
end

//*********************************************************************************************
//*********************************************************************************************

Function IN2R_FindOptimumAvalue(Evalue)						//does the fitting itself, call with precision (e~0.1 or so)
	variable Evalue	

	Wave Intensity

	variable LogAmax=100, LogAmin=-100, M=numpnts(Intensity)
	variable tolerance=Evalue*sqrt(2*M)
	variable ChiSquared, MidPoint, Avalue, i=0
	do
		MidPoint=(LogAmax+LogAmin)/2
		Avalue=10^MidPoint								//calculate A
		IN2R_CalculateAmatrix(Avalue)
		MatrixLUD A_matrix								//decompose A_matrix 
		Wave M_Lower									//results in these matrices for next step:
		Wave M_Upper
		Wave W_LUPermutation
		Wave B_vector
		MatrixLUBkSub M_Lower, M_Upper, W_LUPermutation, B_vector				//Backsubstitute B to get x[]=inverse(A[][]) B[]	
		Wave M_x										//this is created by MatrixMultiply

		Redimension/N=(-1,0) M_x							//create from M_x[..][0] only M_x[..] so it is simple wave
		Duplicate/O M_x CurrentResultSizeDistribution		//put the data into the wave 
		Note/K CurrentResultSizeDistribution
		Note CurrentResultSizeDistribution, note(intensity)
		CurrentResultSizeDistribution/=2					//this fixes conversion to presentation in diameters
		
		ChiSquared=IN2R_CalculateChiSquare()				//Calculate C 	C=|| I - G M_x ||

		print num2str(i+1)+")     Chi squared value:  " + num2str(ChiSquared) + ",    target value:   "+num2str(M)

		if (ChiSquared>M)
			LogAMax=MidPoint
		else
			LogAmin=MidPoint
		endif
		i+=1
		if (i>40)											//no solution found
			abort "too many iterations..."
		endif
	while(abs(ChiSquared-M)>tolerance)
	
	SVAR 	SizesParameters						//record the data
	SizesParameters=ReplaceStringByKey("RegIterations", SizesParameters, num2str(i),"=")
	SizesParameters=ReplaceStringByKey("RegChiSquared", SizesParameters, num2str(ChiSquared),"=")
	SizesParameters=ReplaceStringByKey("RegFinalAparam", SizesParameters, num2str(Avalue),"=")

	IN2G_AppendAnyText("Fitted with following parameters :\r"+SizesParameters)

end
//*********************************************************************************************
//*********************************************************************************************

Function IN2R_CalculateAmatrix(aValue)					//generates A matrix
	variable aValue
	Wave D_matrix
	Wave H_matrix
	
	Duplicate/O D_matrix A_matrix
	A_matrix=0
	A_matrix=D_matrix[p][q]+aValue*H_matrix[p][q]
end

//*********************************************************************************************
//*********************************************************************************************

Function IN2R_CalculateChiSquare()			//calculates chisquared difference between the data
		//in Intensity and result calculated by G_matrix x x_vector
	Wave Intensity
	Wave G_matrix
	Wave Errors
	Wave M_x

	Duplicate/O Intensity, NormalizedResidual, ChiSquaredWave	//waves for data
	IN2G_AppendorReplaceWaveNote("NormalizedResidual","Units"," ")
	
	
	MatrixMultiply  G_matrix, M_x				//generates scattering intesity from current result (M_x - before correction for contrast and diameter)
	Wave M_product	
	Redimension/N=(-1,0) M_product			//again make the matrix with one dimension 0 into regular wave

	Duplicate/O M_product SizesFitIntensity
	Note/K SizesFitIntensity
	Note SizesFitIntensity, note(Intensity)

	NormalizedResidual=(Intensity-M_product)/Errors		//we need this for graph
	ChiSquaredWave=NormalizedResidual^2			//and this is wave with ChiSquared
	return (sum(ChiSquaredWave,-inf,inf))				//return sum of chiSquared
end

//*********************************************************************************************
//*********************************************************************************************

Function IN2R_FinishGraph()			//finish the graph to proper way,  this will be really difficult to make Mac compatible
	string fldrName
	Wave CurrentResultSizeDistribution
	Wave D_distribution
	Wave SizesFitIntensity
	Wave Q_vec
	Wave IntensityOriginal
	Wave NormalizedResidual
	Wave Q_vecOriginal
	SVAR SizesParameters
	Wave BackgroundWave
	
	variable csrApos
	variable csrBpos
	
	if (strlen(csrWave(A))!=0)
		csrApos=pcsr(A)
	else
		csrApos=0
	endif	
	 
	if (strlen(csrWave(B))!=0)
		csrBpos=pcsr(B)
	else
		csrBpos=numpnts(IntensityOriginal)-1
	endif	

	PauseUpdate
	RemoveFromGraph/Z/W=IN2R_SizesInputGraph SizesFitIntensity
	RemoveFromGraph/Z/W=IN2R_SizesInputGraph BackgroundWave
	RemoveFromGraph/Z/W=IN2R_SizesInputGraph CurrentResultSizeDistribution
	RemoveFromGraph/Z/W=IN2R_SizesInputGraph NormalizedResidual
	RemoveFromGraph/Z/W=IN2R_SizesInputGraph IntensityOriginal
	RemoveFromGraph/Z/W=IN2R_SizesInputGraph Intensity
	
	AppendToGraph/T/R/W=IN2R_SizesInputGraph CurrentResultSizeDistribution vs D_distribution
	
	WaveStats/Q CurrentResultSizeDistribution
	if (V_min>0)
		SetAxis/N=1 right 0,V_max*1.1 
	else
		SetAxis/N=1 right -(V_max*0.1),V_max*1.1
	endif
	AppendToGraph/W=IN2R_SizesInputGraph Intensity vs Q_vec
	AppendToGraph/W=IN2R_SizesInputGraph SizesFitIntensity vs Q_vec
	AppendToGraph/W=IN2R_SizesInputGraph BackgroundWave vs Q_vecOriginal
	AppendToGraph/W=IN2R_SizesInputGraph IntensityOriginal vs Q_vecOriginal
	AppendToGraph/W=IN2R_SizesInputGraph/L=ChiSquaredAxis NormalizedResidual vs Q_vec
	ModifyGraph/W=IN2R_SizesInputGraph log(left)=1
	ModifyGraph/W=IN2R_SizesInputGraph log(bottom)=1
	Label/W=IN2R_SizesInputGraph top "Particle diameter [A]"
	ModifyGraph/W=IN2R_SizesInputGraph lblMargin(top)=40
	Label/W=IN2R_SizesInputGraph right "Particle distribution f(D)"
	Label/W=IN2R_SizesInputGraph left "Intensity"
	ModifyGraph/W=IN2R_SizesInputGraph lblPos(left)=50
	ModifyGraph/W=IN2R_SizesInputGraph lblMargin(right)=20
	Label/W=IN2R_SizesInputGraph bottom "Q vector [A\\S-1\\M]"	
	ModifyGraph/W=IN2R_SizesInputGraph axisEnab(left)={0.15,1}
	ModifyGraph/W=IN2R_SizesInputGraph axisEnab(right)={0.15,1}
	ModifyGraph/W=IN2R_SizesInputGraph lblMargin(top)=30
	ModifyGraph/W=IN2R_SizesInputGraph axisEnab(ChiSquaredAxis)={0,0.15}
	ModifyGraph/W=IN2R_SizesInputGraph freePos(ChiSquaredAxis)=0
	Label/W=IN2R_SizesInputGraph ChiSquaredAxis "Residuals"
	ModifyGraph/W=IN2R_SizesInputGraph lblPos(ChiSquaredAxis)=50,lblLatPos=0
	ModifyGraph/W=IN2R_SizesInputGraph mirror(ChiSquaredAxis)=1
	SetAxis/W=IN2R_SizesInputGraph /A/E=2 ChiSquaredAxis
	ModifyGraph/W=IN2R_SizesInputGraph nticks(ChiSquaredAxis)=3

	ModifyGraph/W=IN2R_SizesInputGraph mode(Intensity)=3,marker(Intensity)=5,msize(Intensity)=3
	
	Cursor/P/W=IN2R_SizesInputGraph A IntensityOriginal, csrApos
	Cursor/P/W=IN2R_SizesInputGraph B IntensityOriginal, csrBpos
	
	ModifyGraph/W=IN2R_SizesInputGraph rgb(SizesFitIntensity)=(0,0,52224)	
	ModifyGraph/W=IN2R_SizesInputGraph lstyle(BackgroundWave)=3

	ModifyGraph/W=IN2R_SizesInputGraph mode(IntensityOriginal)=3
	ModifyGraph/W=IN2R_SizesInputGraph msize(IntensityOriginal)=2
	ModifyGraph/W=IN2R_SizesInputGraph rgb(IntensityOriginal)=(0,52224,0)
	ModifyGraph/W=IN2R_SizesInputGraph zmrkNum(IntensityOriginal)={DeletePointsMaskWave}
	ErrorBars/W=IN2R_SizesInputGraph IntensityOriginal Y,wave=(DeletePointsMaskErrorWave,DeletePointsMaskErrorWave)

	ModifyGraph/W=IN2R_SizesInputGraph mode(CurrentResultSizeDistribution)=5
	ModifyGraph/W=IN2R_SizesInputGraph hbFill(CurrentResultSizeDistribution)=4	
	ModifyGraph/W=IN2R_SizesInputGraph useNegRGB(CurrentResultSizeDistribution)=1
	ModifyGraph/W=IN2R_SizesInputGraph usePlusRGB(CurrentResultSizeDistribution)=1
	ModifyGraph/W=IN2R_SizesInputGraph hbFill(CurrentResultSizeDistribution)=12
	ModifyGraph/W=IN2R_SizesInputGraph plusRGB(CurrentResultSizeDistribution)=(32768,65280,0)
	ModifyGraph/W=IN2R_SizesInputGraph negRGB(CurrentResultSizeDistribution)=(32768,65280,0)

	ModifyGraph/W=IN2R_SizesInputGraph mode(NormalizedResidual)=3,marker(NormalizedResidual)=19
	ModifyGraph/W=IN2R_SizesInputGraph msize(NormalizedResidual)=1
	

	IN2G_GenerateLegendForGraph(7,0)
	Legend/C/N=N2R_Regularizatio/J/A=RT/X=0/Y=0

	DoUpdate						//and here we again record what we have done
	IN2G_AppendStringToWaveNote("CurrentResultSizeDistribution",SizesParameters)	
	IN2G_AppendStringToWaveNote("D_distribution",SizesParameters)	
	IN2G_AppendStringToWaveNote("SizesFitIntensity",SizesParameters)	
	IN2G_AppendStringToWaveNote("Q_vec",SizesParameters)	
end

//***********************************************************************************************************
//***********************************************************************************************************

Function IN2R_ReturnFitBack()			//copies data back to folder with original data
	SVAR fldrName
	Wave CurrentResultSizeDistribution
	Wave D_distribution
	Wave SizesFitIntensity
	Wave Q_vec
	Wave NormalizedResidual
	SVAR SizesParameters
	
	string tempname
	tempname=fldrName+"RegularSizeDistributionFD"
	IN2G_AppendorReplaceWaveNote("CurrentResultSizeDistribution","Wname","RegularSizeDistributionFD")
	Duplicate/O CurrentResultSizeDistribution $tempname

	tempname=fldrName+"RegularSizeDistDiameter"
	IN2G_AppendorReplaceWaveNote("D_distribution","Wname","RegularSizeDistDiameter")
	Duplicate/O D_distribution $tempname

	tempname=fldrName+"RegularFitIntensity"
	IN2G_AppendorReplaceWaveNote("SizesFitIntensity","Wname","RegularFitIntensity")
	Duplicate/O SizesFitIntensity $tempname

	tempname=fldrName+"RegularFitQvector"
	IN2G_AppendorReplaceWaveNote("Q_vec","Wname","RegularFitQvector")
	Duplicate/O Q_vec $tempname
	
	IN2R_CalcOtherDistributions()	//this function goes to original data folder and calculates new waves with other results
								//but writes results into old Sizesparameters, therefore we need to return back
								//and copy the SizesParameters to the original folder
	tempname=fldrName+"SizesParameters"
	string/G $tempName=SizesParameters

end 


//*********************************************************************************************
//*********************************************************************************************

Window IN2R_SizesInputPanel() : Panel
	PauseUpdate; Silent 1		// building window...
	NewPanel /K=1 /W=(549,47.75,903.75,569)
	SetDrawLayer UserBack
	SetDrawEnv fsize= 16,fstyle= 1,textrgb= (65280,0,0)
	DrawText 13,24,"Sizes input parameters"
	SetDrawEnv fsize= 14,fstyle= 1,textrgb= (0,0,52224)
	DrawText 13,436,"Set range of data to fit with cursors!!"
	SetDrawEnv gstart
	SetDrawEnv gstop
	DrawLine 7,121,348,121
	DrawText 174,471,"You need to save the results"
	DrawText 201,495,"or they are lost!!"
	DrawLine 7,263,347,263
	DrawLine 7,336,347,336
	SetVariable RminInput,pos={13,32},size={150,16},title="Minimum diameter"
	SetVariable RminInput,limits={1,Inf,5},value= root:Packages:Sizes:Dmin
	SetVariable RmaxInput,pos={180,33},size={150,16},title="Maximum diameter"
	SetVariable RmaxInput,limits={1,Inf,5},value= root:Packages:Sizes:Dmax
	PopupMenu Binning,pos={5,91},size={198,21},proc=IN2R_ChangeBinningMethod,title="Logaritmic binning method?"
	PopupMenu Binning,mode=1,popvalue=root:Packages:Sizes:LogDist,value= #"\"Yes;No\""
	SetVariable RadiaSteps,pos={24,63},size={150,16},title="Bins in diameter"
	SetVariable RadiaSteps,limits={1,Inf,5},value= root:Packages:Sizes:numOfPoints
	SetVariable Background,pos={10,131},size={200,16},proc=IN2R_BackgroundInput,title="Subtract Background"
	SetVariable Background,limits={-Inf,Inf,0.001},value= root:Packages:Sizes:Bckg
	PopupMenu ShapeModel,pos={11,271},size={220,21},proc=IN2R_SelectShapeModel,title="Select particle shape model"
	PopupMenu ShapeModel,mode=1,popvalue=root:Packages:Sizes:ShapeType,value= #"\"Spheroid;no other available yet\""
	Button RunSizes,pos={12,443},size={150,20},proc=IN2R_SizesFitting,title="Run Sizes"
	Button SaveData,pos={12,470},size={150,20},proc=IN2R_saveData,title="Save the results"
	Button Restart,pos={12,495},size={150,20},proc=IN2R_restart,title="Start with new data"
	SetVariable ScatteringContrast,pos={10,153},size={250,16},title="Contrast (drho^2)[10^20, 1/cm4]"
	SetVariable ScatteringContrast,limits={0,Inf,1},value= root:Packages:Sizes:ScatteringContrast
	SetVariable ErrorMultiplier,pos={10,175},size={250,16},title="Multiply Errors by : "
	SetVariable ErrorMultiplier,limits={0,Inf,1},value= root:Packages:Sizes:ErrorsMultiplier
	SetVariable AspectRatio,pos={16,303},size={220,16},title="Aspect Ratio (when needed)"
	SetVariable AspectRatio,limits={0,Inf,0.1},value= root:Packages:Sizes:AspectRatio
	PopupMenu SlitSmearedData,pos={40,210},size={205,21},proc=IN2R_ChangeSmeared,title="Slit smeared data?"
	PopupMenu SlitSmearedData,mode=1,popvalue=root:Packages:Sizes:SlitSmearedData,value= #"\"No;Yes\""
	SetVariable SlitLength,pos={50,240},size={150,16},title="Slit Length"
	SetVariable SlitLength,limits={0,Inf,0.001},value= root:Packages:Sizes:SlitLength
EndMacro

//*********************************************************************************************
//*********************************************************************************************

Function IN2R_ChangeBinningMethod(ctrlName,popNum,popStr) : PopupMenuControl
	String ctrlName
	Variable popNum
	String popStr

	SVAR LogDist
	
	LogDist=popStr
End

Function IN2R_ChangeSmeared(ctrlName,popNum,popStr) : PopupMenuControl
	String ctrlName
	Variable popNum
	String popStr

	SVAR SlitSmearedData
	SVAR SizesParameters
	SlitSmearedData=popStr
	SizesParameters=ReplaceStringByKey("RegSlitSmearedData",SizesParameters,popStr,"=")
End

//*********************************************************************************************
//*********************************************************************************************

Window IN2R_SizesInputGraph() : Graph
	PauseUpdate; Silent 1		// building window...
	SetDataFolder root:Packages:Sizes:
	Display /W=(0.3*IN2G_ScreenWidthHeight("width"),5*IN2G_ScreenWidthHeight("heigth"),60*IN2G_ScreenWidthHeight("width"),80*IN2G_ScreenWidthHeight("height")) IntensityOriginal vs Q_vecOriginal
	IN2R_AppendIntOriginal()	
	AppendToGraph BackgroundWave vs Q_vecOriginal
	ModifyGraph/Z margin(top)=80
	Button RemovePointR pos={150,10}, size={140,20}, title="Remove pnt w/csrA", proc=IN2R_RemovePointWithCursorA
	Button ReturnAllPoints pos={150,40}, size={140,20}, title="Return All deleted points", proc=IN2R_ReturnAllDeletedPoints
	Button KillThisWindow pos={10,10}, size={100,25}, title="Kill window", proc=IN2G_KillGraphsAndTables
	Button ResetWindow pos={10,40}, size={100,25}, title="Reset window", proc=IN2G_ResetGraph
	ModifyGraph log=1
	Label left "Intensity"
	ModifyGraph lblPos(left)=50
	Label bottom "Q vector [A\\S-1\\M]"
	ShowInfo
	Textbox/N=text0/S=3/A=RT "The sample evaluated is:  "+StringByKey("UserSampleName", note(IntensityOriginal), "=")
	DoUpdate

EndMacro
//*********************************************************************************************
//*********************************************************************************************
Function IN2R_AppendIntOriginal()		//appends (and removes) and configures in graph IntOriginal vs Qvec Original
	
	Wave IntensityOriginal
	Wave Q_vecOriginal
	Wave DeletePointsMaskErrorWave
	variable csrApos
	variable csrBpos
	
	if (strlen(csrWave(A))!=0)
		csrApos=pcsr(A)
	else
		csrApos=0
	endif	
		
	 
	if (strlen(csrWave(B))!=0)
		csrBpos=pcsr(B)
	else
		csrBpos=numpnts(IntensityOriginal)-1
	endif	

	RemoveFromGraph/Z IntensityOriginal
	AppendToGraph IntensityOriginal vs Q_vecOriginal

	Label left "Intensity"
	ModifyGraph lblPos(left)=50
	Label bottom "Q vector [A\\S-1\\M]"

	ModifyGraph mode(IntensityOriginal)=3
	ModifyGraph msize(IntensityOriginal)=2
	ModifyGraph rgb(IntensityOriginal)=(0,52224,0)
	ModifyGraph zmrkNum(IntensityOriginal)={DeletePointsMaskWave}
	ErrorBars IntensityOriginal Y,wave=(DeletePointsMaskErrorWave,DeletePointsMaskErrorWave)
	Cursor/P A IntensityOriginal, csrApos
	Cursor/P B IntensityOriginal, csrBpos

end

Function IN2R_RemovePointWithCursorA(ctrlname) : Buttoncontrol			// Removes point in wave
	string ctrlname
	
	Wave DeletePointsMaskWave
	Wave DeletePointsMaskErrorWave
	
	DeletePointsMaskWave[pcsr(A)]=NaN
	DeletePointsMaskErrorWave[pcsr(A)]=NaN
	
	IN2R_AppendIntOriginal()	

End

Function IN2R_ReturnAllDeletedPoints(ctrlname) : Buttoncontrol			// Removes point in wave
	string ctrlname
	
	Wave DeletePointsMaskWave
	Wave DeletePointsMaskErrorWave
	Wave ErrorsOriginal
	
	DeletePointsMaskErrorWave=ErrorsOriginal
	DeletePointsMaskWave=7

	IN2R_AppendIntOriginal()	
End

//*********************************************************************************************
//*********************************************************************************************


Function IN2R_BackgroundInput(ctrlName,varNum,varStr,varName) : SetVariableControl
	String ctrlName
	Variable varNum
	String varStr
	String varName

	Wave Q_vec
	Duplicate/O Q_vecOriginal BackgroundWave
	BackgroundWave=varNum
	CheckDisplayed BackgroundWave 
	if (!V_Flag)
		AppendToGraph BackgroundWave vs Q_vecOriginal
	endif
End
//*********************************************************************************************
//*********************************************************************************************

Function IN2R_SelectShapeModel(ctrlName,popNum,popStr) : PopupMenuControl
	String ctrlName
	Variable popNum
	String popStr

	SVAR ShapeType
	ShapeType=popStr
End


//*********************************************************************************************
//*********************************************************************************************

Function IN2R_restart(ctrlName) : ButtonControl
	String ctrlName
	
	IN2G_KillAllGraphsAndTables("yes")		//kills the graph and panel
	
	IN2R_Sizes()						//restarts the procredure
End

//*********************************************************************************************
//*********************************************************************************************

Function IN2R_saveData(ctrlName) : ButtonControl
	String ctrlName

	IN2R_ReturnFitBack()		//and this returns the data to original folder
End


//*********************************************************************************************
//*********************************************************************************************
Function IN2R_ShrinkGMatrixAfterSmearing()		//this shrinks the G_matrix and Q_vec back
												//Errors are used to get originasl length
	Wave G_matrix
	Wave Q_vec
	Wave Errors
	
	variable OldLength=numpnts(Errors)				//this is old number of points (Erros length did not change during smearing)
	
	redimension/N=(OldLength) Q_vec				//this shrinks the Q_veck to old length
	
	redimension/N=(OldLength,-1) G_matrix			//this shrinks the G_matrix to original number of rows, columns stay same

end
//*********************************************************************************************
//*********************************************************************************************
Function IN2R_SmearGMatrix()			//this function smears the colums in the G matrix

	Wave G_matrix
	Wave Q_vec
	NVAR SlitLength

	variable M=DimSize(G_matrix, 0)							//rows, i.e, measured points 
	variable N=DimSize(G_matrix, 1)							//columns, i.e., bins in radius distribution
	variable i=0
	Make/D/O/N=(M) tempOrg, tempSmeared									//points = measured Q points

	for (i=0;i<N;i+=1)					//for each column (radius point)
		tempOrg=G_matrix[p][i]			//column -> temp
		
		IN2D_SmearData(tempOrg, Q_vec, slitLength, tempSmeared)			//temp is smeared (Q_vec, SlitLength) ->  tempSmeared
	
		G_matrix[][i]=tempSmeared[p]		//column in G is set to smeared value
	endfor

//	G_matrix*=SlitLength*1e-4				//try to fix calibration
end


//*********************************************************************************************
//*********************************************************************************************
Function IN2R_ExtendQVecForSmearing()		//this is function extends the Q vector for smearing

	Wave Q_vec
	NVAR SlitLength

	variable OldPnts=numpnts(Q_vec)
	variable qmax=Q_vec[OldPnts-1]
	variable newNumPnts=0
	
	Duplicate Q_vec, TempWv	
	TempWv=log(Q_vec)

	if (qmax<SlitLength)
		NewNumPnts=numpnts(Q_vec)
	else
		NewNumPnts=numpnts(Q_vec)-BinarySearch(Q_vec, (Q_vec[OldPnts-1]-SlitLength) )
	endif
	
	if (NewNumPnts<10)
		NewNumPnts=10
	endif
	
	Make/O/D/N=(NewNumPnts) Extension
	Extension=Q_vec[OldPnts-1]+p*(SlitLength/NewNumPnts)
	Redimension /N=(OldPnts+NewNumPnts) Q_vec
	Q_vec[OldPnts, OldPnts+NewNumPnts-1]=Extension[p-OldPnts]
	
	KillWaves TempWv, Extension
end

//*********************************************************************************************
//*********************************************************************************************
Function IN2R_CalcOtherDistributions()

	SVAR fldrName
	SVAR SizesParameters
	
	string dfold=GetDataFolder(1)
	
	setDataFolder $fldrName
	
	WAVE RegularSizeDistributionFD
	WAVE RegularSizeDistDiameter
	WAVE RegularFitIntensity
	WAVE RegularFitQvector
	
	//and here we are in the proper folder and need to calculate some parameters
	
	string shape=StringByKey("RegParticleShape", SizesParameters,"=")
	variable Aspectratio=NumberByKey("RegAspectRatio", SizesParameters,"=")

	Duplicate/O RegularSizeDistributionFD, RegularVolumeDistribution, RegularNumberDistribution

	RegularNumberDistribution=RegularSizeDistributionFD/(AspectRatio*(4/3)*pi*((RegularSizeDistDiameter*1e-8)/2)^3)

	variable MeanSize=IN2R_MeanOfDistribution(RegularVolumeDistribution,RegularSizeDistDiameter)

	IN2G_AppendorReplaceWaveNote("RegularVolumeDistribution","Wname","RegularVolumeDistribution")
	IN2G_AppendorReplaceWaveNote("RegularVolumeDistribution","Units","cm3/cm3")
	IN2G_AppendorReplaceWaveNote("RegularVolumeDistribution","MeanSizeOfDistribution",num2str(MeanSize))
	IN2G_AppendorReplaceWaveNote("RegularNumberDistribution","Wname","RegularNumberDistribution")
	IN2G_AppendorReplaceWaveNote("RegularNumberDistribution","Units","1/cm3")
	IN2G_AppendorReplaceWaveNote("RegularNumberDistribution","MeanSizeOfDistribution",num2str(MeanSize))
	
	
	print "Mean size of distribution"+num2str(MeanSize)

	SizesParameters=ReplaceStringByKey("MeanSizeOfDistribution", SizesParameters, num2str(MeanSize),"=")

	setDataFolder $dfold
end


Function IN2R_MeanOfDistribution(VolDist,Dia)
	Wave VolDist, Dia
	variable result=0, i, imax=numpnts(VolDist), VolTotal=0
	
	if (numpnts(VolDist)!=numpnts(Dia))
		Abort "Error in IN2R_MeanOfDistribution, the waves do not have the length"
	endif
	
	for(i=0;i<imax;i+=1)					// initialize variables;continue test
		if (VolDist[i]>=0)
			result+=VolDist[i]*Dia[i]
			VolTotal+=VolDist[i]
		endif
	endfor								// execute body code until continue test is false
 
 	result = result/VolTotal
	
	return result

end
//*********************************************************************************************
//*********************************************************************************************
