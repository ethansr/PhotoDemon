VERSION 5.00
Begin VB.Form FormWaves 
   AutoRedraw      =   -1  'True
   BackColor       =   &H80000005&
   BorderStyle     =   4  'Fixed ToolWindow
   Caption         =   " Waves"
   ClientHeight    =   6540
   ClientLeft      =   -15
   ClientTop       =   225
   ClientWidth     =   12090
   BeginProperty Font 
      Name            =   "Tahoma"
      Size            =   8.25
      Charset         =   0
      Weight          =   400
      Underline       =   0   'False
      Italic          =   0   'False
      Strikethrough   =   0   'False
   EndProperty
   LinkTopic       =   "Form1"
   MaxButton       =   0   'False
   MinButton       =   0   'False
   ScaleHeight     =   436
   ScaleMode       =   3  'Pixel
   ScaleWidth      =   806
   ShowInTaskbar   =   0   'False
   Begin PhotoDemon.pdCommandBar cmdBar 
      Align           =   2  'Align Bottom
      Height          =   750
      Left            =   0
      TabIndex        =   0
      Top             =   5790
      Width           =   12090
      _ExtentX        =   21325
      _ExtentY        =   1323
   End
   Begin PhotoDemon.pdFxPreviewCtl pdFxPreview 
      Height          =   5625
      Left            =   120
      TabIndex        =   1
      Top             =   120
      Width           =   5625
      _ExtentX        =   9922
      _ExtentY        =   9922
      DisableZoomPan  =   -1  'True
   End
   Begin PhotoDemon.pdSlider sltWavelengthX 
      Height          =   705
      Left            =   6000
      TabIndex        =   3
      Top             =   120
      Width           =   5895
      _ExtentX        =   10398
      _ExtentY        =   1270
      Caption         =   "horizontal wavelength"
      Min             =   1
      Max             =   50
      Value           =   30
      DefaultValue    =   30
   End
   Begin PhotoDemon.pdSlider sltWavelengthY 
      Height          =   705
      Left            =   6000
      TabIndex        =   4
      Top             =   1860
      Width           =   5895
      _ExtentX        =   10398
      _ExtentY        =   1270
      Caption         =   "vertical wavelength"
      Min             =   1
      Max             =   50
      Value           =   1
      DefaultValue    =   1
   End
   Begin PhotoDemon.pdSlider sltAmplitudeX 
      Height          =   705
      Left            =   6000
      TabIndex        =   5
      Top             =   990
      Width           =   5895
      _ExtentX        =   10398
      _ExtentY        =   1270
      Caption         =   "horizontal strength (amplitude)"
      Max             =   200
      Value           =   20
      DefaultValue    =   20
   End
   Begin PhotoDemon.pdSlider sltAmplitudeY 
      Height          =   705
      Left            =   6000
      TabIndex        =   6
      Top             =   2730
      Width           =   5895
      _ExtentX        =   10398
      _ExtentY        =   1270
      Caption         =   "vertical strength (amplitude)"
      Max             =   200
   End
   Begin PhotoDemon.pdSlider sltQuality 
      Height          =   705
      Left            =   6000
      TabIndex        =   7
      Top             =   3600
      Width           =   5895
      _ExtentX        =   10398
      _ExtentY        =   1270
      Caption         =   "quality"
      Min             =   1
      Max             =   5
      Value           =   2
      NotchPosition   =   2
      NotchValueCustom=   2
   End
   Begin PhotoDemon.pdDropDown cboEdges 
      Height          =   375
      Left            =   6240
      TabIndex        =   2
      Top             =   4800
      Width           =   5655
      _ExtentX        =   9975
      _ExtentY        =   661
   End
   Begin PhotoDemon.pdLabel lblTitle 
      Height          =   285
      Left            =   6000
      Top             =   4440
      Width           =   5955
      _ExtentX        =   0
      _ExtentY        =   0
      Caption         =   "if pixels lie outside the image..."
      FontSize        =   12
      ForeColor       =   4210752
   End
End
Attribute VB_Name = "FormWaves"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
'***************************************************************************
'Image "Waves" Distortion
'Copyright 2000-2016 by Tanner Helland
'Created: 07/January/13
'Last updated: 27/September/14
'Last update: add supersampling support
'
'This tool allows the user to apply a "waves" distortion to an image.  Supersampling and reverse-mapping
' (with interpolation) are available for a high-quality result.
'
'Four parameters are required - wavelength and amplitude for both the x and y directions.  Unlike other distortions
' in PhotoDemon, this one doesn't require a radius.
'
'Finally, the transformation used by this tool is a modified version of a transformation originally written by
' Jerry Huxtable of JH Labs.  Jerry's original code is licensed under an Apache 2.0 license.  You may download his
' original version at the following link (good as of 07 January '13): http://www.jhlabs.com/ip/filters/index.html
'
'All source code in this file is licensed under a modified BSD license.  This means you may use the code in your own
' projects IF you provide attribution.  For more information, please visit http://photodemon.org/about/license/
'
'***************************************************************************

Option Explicit

Private Sub cboEdges_Click()
    UpdatePreview
End Sub

'Apply a "wave-like" effect to an image
Public Sub WaveImage(ByVal xWavelength As Double, ByVal xAmplitude As Double, ByVal yWavelength As Double, ByVal yAmplitude As Double, ByVal edgeHandling As Long, ByVal superSamplingAmount As Long, Optional ByVal toPreview As Boolean = False, Optional ByRef dstPic As pdFxPreviewCtl)

    If Not toPreview Then Message "Dipping image in virtual wave pool..."
        
    'Create a local array and point it at the pixel data of the current image
    Dim dstImageData() As Byte
    Dim dstSA As SAFEARRAY2D
    PrepImageData dstSA, toPreview, dstPic
    CopyMemory ByVal VarPtrArray(dstImageData()), VarPtr(dstSA), 4
    
    'Create a second local array.  This will contain the a copy of the current image, and we will use it as our source reference
    ' (This is necessary to prevent diffused pixels from spreading across the image as we go.)
    Dim srcImageData() As Byte
    Dim srcSA As SAFEARRAY2D
    
    Dim srcDIB As pdDIB
    Set srcDIB = New pdDIB
    srcDIB.CreateFromExistingDIB workingDIB
    
    PrepSafeArray srcSA, srcDIB
    CopyMemory ByVal VarPtrArray(srcImageData()), VarPtr(srcSA), 4
        
    'Local loop variables can be more efficiently cached by VB's compiler, so we transfer all relevant loop data here
    Dim x As Long, y As Long, initX As Long, initY As Long, finalX As Long, finalY As Long
    initX = curDIBValues.Left
    initY = curDIBValues.Top
    finalX = curDIBValues.Right
    finalY = curDIBValues.Bottom
            
    'These values will help us access locations in the array more quickly.
    ' (qvDepth is required because the image array may be 24 or 32 bits per pixel, and we want to handle both cases.)
    Dim QuickVal As Long, qvDepth As Long
    qvDepth = curDIBValues.BytesPerPixel
    
    'Create a filter support class, which will aid with edge handling and interpolation
    Dim fSupport As pdFilterSupport
    Set fSupport = New pdFilterSupport
    fSupport.setDistortParameters qvDepth, edgeHandling, (superSamplingAmount <> 1), curDIBValues.maxX, curDIBValues.MaxY
    
    'To keep processing quick, only update the progress bar when absolutely necessary.  This function calculates that value
    ' based on the size of the area to be processed.
    Dim progBarCheck As Long
    progBarCheck = FindBestProgBarValue()
    
    '***************************************
    ' /* BEGIN SUPERSAMPLING PREPARATION */
    
    'Due to the way this filter works, supersampling yields much better results.  Because supersampling is extremely
    ' energy-intensive, this tool uses a sliding value for quality, as opposed to a binary TRUE/FALSE for antialiasing.
    ' (For all but the lowest quality setting, antialiasing will be used, and higher quality values will simply increase
    '  the amount of supersamples taken.)
    Dim newR As Long, newG As Long, newB As Long, newA As Long
    Dim r As Long, g As Long, b As Long, a As Long
    Dim tmpSum As Long, tmpSumFirst As Long
    
    'Use the passed super-sampling constant (displayed to the user as "quality") to come up with a number of actual
    ' pixels to sample.  (The total amount of sampled pixels will range from 1 to 13).  Note that supersampling
    ' coordinates are precalculated and cached using a modified rotated grid function, which is consistent throughout PD.
    Dim numSamples As Long
    Dim ssX() As Single, ssY() As Single
    Filters_Area.getSupersamplingTable superSamplingAmount, numSamples, ssX, ssY
    
    'Because supersampling will be used in the inner loop as (samplecount - 1), permanently decrease the sample
    ' count in advance.
    numSamples = numSamples - 1
    
    'Additional variables are needed for supersampling handling
    Dim j As Double, k As Double
    Dim sampleIndex As Long, numSamplesUsed As Long
    Dim superSampleVerify As Long, ssVerificationLimit As Long
    
    'Adaptive supersampling allows us to bypass supersampling if a pixel doesn't appear to benefit from it.  The superSampleVerify
    ' variable controls how many pixels are sampled before we perform an adaptation check.  At present, the rule is:
    ' Quality 3: check a minimum of 2 samples, Quality 4: check minimum 3 samples, Quality 5: check minimum 4 samples
    superSampleVerify = superSamplingAmount - 2
    
    'Alongside a variable number of test samples, adaptive supersampling requires some threshold that indicates samples
    ' are close enough that further supersampling is unlikely to improve output.  We calculate this as a minimum variance
    ' as 1.5 per channel (for a total of 6 variance per pixel), multiplied by the total number of samples taken.
    ssVerificationLimit = superSampleVerify * 6
    
    'To improve performance for quality 1 and 2 (which perform no supersampling), we can forcibly disable supersample checks
    ' by setting the verification checker to some impossible value.
    If superSampleVerify <= 0 Then superSampleVerify = LONG_MAX
    
    ' /* END SUPERSAMPLING PREPARATION */
    '*************************************
    
    'This wave transformation requires specialized variables
    xWavelength = 51 - xWavelength
    yWavelength = 51 - yWavelength
    
    'During a preview, modify the wavelength and amplitude values to make the preview representative of the final image
    If toPreview Then
        xWavelength = xWavelength * curDIBValues.previewModifier
        yWavelength = yWavelength * curDIBValues.previewModifier
        xAmplitude = xAmplitude * curDIBValues.previewModifier
        yAmplitude = yAmplitude * curDIBValues.previewModifier
    End If
    
    'X and Y values, remapped around a center point of (0, 0)
    Dim nX As Double, nY As Double
    
    'Source X and Y values, which may or may not be used as part of a bilinear interpolation function
    Dim srcX As Double, srcY As Double
                     
    'Loop through each pixel in the image, converting values as we go
    For x = initX To finalX
        QuickVal = x * qvDepth
    For y = initY To finalY
    
        'Reset all supersampling values
        newR = 0
        newG = 0
        newB = 0
        newA = 0
        numSamplesUsed = 0
        
        'Remap the coordinates around a center point of (0, 0)
        j = y - yAmplitude
        k = x - xAmplitude
        
        'Sample a number of source pixels corresponding to the user's supplied quality value; more quality means
        ' more samples, and much better representation in the final output.
        For sampleIndex = 0 To numSamples
            
            'Offset the pixel amount by the supersampling lookup table and wavelength
            nX = (j + ssX(sampleIndex)) / xWavelength
            nY = (k + ssY(sampleIndex)) / yWavelength
            
            'Further extend pixel coordinates by sin() * amplitude
            srcX = x + Sin(nX) * xAmplitude
            srcY = y + Sin(nY) * yAmplitude
            
            'Use the filter support class to interpolate and edge-wrap pixels as necessary
            fSupport.getColorsFromSource r, g, b, a, srcX, srcY, srcImageData, x, y
            
            'If adaptive supersampling is active, apply the "adaptive" aspect.  Basically, calculate a variance for the currently
            ' collected samples.  If variance is low, assume this pixel does not require further supersampling.
            ' (Note that this is an ugly shorthand way to calculate variance, but it's fast, and the chance of false outliers is
            '  small enough to make it preferable over a true variance calculation.)
            If sampleIndex = superSampleVerify Then
                
                'Calculate variance for the first two pixels (Q3), three pixels (Q4), or four pixels (Q5)
                tmpSum = (r + g + b + a) * superSampleVerify
                tmpSumFirst = newR + newG + newB + newA
                
                'If variance is below 1.5 per channel per pixel, abort further supersampling
                If Abs(tmpSum - tmpSumFirst) < ssVerificationLimit Then Exit For
            
            End If
            
            'Increase the sample count
            numSamplesUsed = numSamplesUsed + 1
            
            'Add the retrieved values to our running averages
            newR = newR + r
            newG = newG + g
            newB = newB + b
            If qvDepth = 4 Then newA = newA + a
            
        Next sampleIndex
        
        'Find the average values of all samples, apply to the pixel, and move on!
        newR = newR \ numSamplesUsed
        newG = newG \ numSamplesUsed
        newB = newB \ numSamplesUsed
        
        dstImageData(QuickVal + 2, y) = newR
        dstImageData(QuickVal + 1, y) = newG
        dstImageData(QuickVal, y) = newB
        
        'If the image has an alpha channel, repeat the calculation there too
        If qvDepth = 4 Then
            newA = newA \ numSamplesUsed
            dstImageData(QuickVal + 3, y) = newA
        End If
                        
    Next y
        If Not toPreview Then
            If (x And progBarCheck) = 0 Then
                If UserPressedESC() Then Exit For
                SetProgBarVal x
            End If
        End If
    Next x
            
    'With our work complete, point both ImageData() arrays away from their DIBs and deallocate them
    CopyMemory ByVal VarPtrArray(srcImageData), 0&, 4
    Erase srcImageData
    
    CopyMemory ByVal VarPtrArray(dstImageData), 0&, 4
    Erase dstImageData
    
    'Pass control to finalizeImageData, which will handle the rest of the rendering
    FinalizeImageData toPreview, dstPic
            
End Sub

'OK button
Private Sub cmdBar_OKClick()
    Process "Waves", , BuildParams(sltWavelengthX, sltAmplitudeX, sltWavelengthY, sltAmplitudeY, CLng(cboEdges.ListIndex), sltQuality), UNDO_LAYER
End Sub

Private Sub cmdBar_RequestPreviewUpdate()
    UpdatePreview
End Sub

Private Sub cmdBar_ResetClick()
    cboEdges.ListIndex = EDGE_REFLECT
    sltQuality.Value = 2
End Sub

Private Sub Form_Activate()
    
    'Apply translations and visual themes
    ApplyThemeAndTranslations Me
    
    'Create the preview
    cmdBar.MarkPreviewStatus True
    UpdatePreview
    
End Sub

Private Sub Form_Load()

    'Suppress previews until the dialog is fully initialized
    cmdBar.MarkPreviewStatus False
    
    'I use a central function to populate the edge handling combo box; this way, I can add new methods and have
    ' them immediately available to all distort functions.
    PopDistortEdgeBox cboEdges, EDGE_REFLECT
    
End Sub

Private Sub Form_Unload(Cancel As Integer)
    ReleaseFormTheming Me
End Sub

Private Sub sltAmplitudeX_Change()
    UpdatePreview
End Sub

Private Sub sltAmplitudeY_Change()
    UpdatePreview
End Sub

Private Sub sltQuality_Change()
    UpdatePreview
End Sub

Private Sub sltWavelengthX_Change()
    UpdatePreview
End Sub

Private Sub sltWavelengthY_Change()
    UpdatePreview
End Sub

'Redraw the on-screen preview of the transformed image
Private Sub UpdatePreview()
    If cmdBar.PreviewsAllowed Then WaveImage sltWavelengthX, sltAmplitudeX, sltWavelengthY, sltAmplitudeY, CLng(cboEdges.ListIndex), sltQuality, True, pdFxPreview
End Sub

'If the user changes the position and/or zoom of the preview viewport, the entire preview must be redrawn.
Private Sub pdFxPreview_ViewportChanged()
    UpdatePreview
End Sub






