VERSION 5.00
Begin VB.Form FormSplash 
   Appearance      =   0  'Flat
   AutoRedraw      =   -1  'True
   BackColor       =   &H00000000&
   BorderStyle     =   0  'None
   ClientHeight    =   3300
   ClientLeft      =   210
   ClientTop       =   1365
   ClientWidth     =   11685
   ControlBox      =   0   'False
   BeginProperty Font 
      Name            =   "Arial"
      Size            =   8.25
      Charset         =   0
      Weight          =   400
      Underline       =   0   'False
      Italic          =   0   'False
      Strikethrough   =   0   'False
   EndProperty
   KeyPreview      =   -1  'True
   LinkTopic       =   "Form2"
   MaxButton       =   0   'False
   MinButton       =   0   'False
   Moveable        =   0   'False
   NegotiateMenus  =   0   'False
   ScaleHeight     =   220
   ScaleMode       =   3  'Pixel
   ScaleWidth      =   779
   ShowInTaskbar   =   0   'False
End
Attribute VB_Name = "FormSplash"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
'***************************************************************************
'PhotoDemon Splash Screen
'Copyright 2001-2016 by Tanner Helland
'Created: 15/April/01
'Last updated: 01/December/14
'Last update: overhauled splash screen
'
'All source code in this file is licensed under a modified BSD license.  This means you may use the code in your own
' projects IF you provide attribution.  For more information, please visit http://photodemon.org/about/license/
'
'***************************************************************************

Option Explicit

Private Declare Function GetWindowRect Lib "user32" (ByVal hWnd As Long, ByRef lpRect As RECTL) As Long
Private Declare Function GetClientRect Lib "user32" (ByVal hWnd As Long, ByRef lpRect As RECTL) As Long

'A logo, drop shadow and screen backdrop are used to generate the splash.  These DIBs are released once splashDIB (below)
' has been successfully assembled.
Private logoDIB As pdDIB, screenDIB As pdDIB, shadowDIB As pdDIB
Private splashDIB As pdDIB

'We skip the entire display process if any of the DIBs can't be created
Private dibsLoadedSuccessfully As Boolean

'Some information is custom-drawn onto the logo at run-time.  pdFont objects are used to render any text.
Private curFontVersion As pdFont

'On high-DPI monitors, some stretching is required.  In the future, I would like to replace this with a more
' elegant solution.
Private logoAspectRatio As Double

'The maximum progress count of the load operation is stored here.  The value is passed to the initial
' prepareSplashLogo function, and it is not modified once loaded.
Private m_MaxProgress As Long, m_ProgressAtFirstNotify As Long

'Load any logo DIBs from the .exe's resource area, and precalculate some rendering values
Public Sub prepareSplashLogo(ByVal maxProgressValue As Long)
    
    m_MaxProgress = maxProgressValue
    m_ProgressAtFirstNotify = -1
    dibsLoadedSuccessfully = False
    
    Set logoDIB = New pdDIB
    Set screenDIB = New pdDIB
    Set shadowDIB = New pdDIB
    
    'Load the logo DIB, and calculate an aspect ratio (important if high-DPI settings are in use)
    dibsLoadedSuccessfully = LoadResourceToDIB("PDLOGOWHITE", logoDIB)
    logoAspectRatio = CDbl(logoDIB.GetDIBWidth) / CDbl(logoDIB.GetDIBHeight)
    
    'Load the inverted logo DIB; this will be blurred and used as a shadow backdrop
    dibsLoadedSuccessfully = dibsLoadedSuccessfully And LoadResourceToDIB("PDLOGOBLACK", shadowDIB)
    
    If FixDPIFloat(1) = 1 Then
        QuickBlurDIB shadowDIB, 7, False
    Else
        QuickBlurDIB shadowDIB, 7 * (1 / FixDPIFloat(1)), False
    End If
    
    'Set the StretchBlt mode of the underlying form in advance
    SetStretchBltMode Me.hDC, STRETCHBLT_HALFTONE
    
End Sub

'Load the form backdrop.  Note that this CANNOT BE DONE until the global monitor classes are initialized.
Public Sub prepareRestOfSplash()
    
    If dibsLoadedSuccessfully Then
    
        'Use the getDesktopAsDIB function to retrieve a copy of the current screen.  We will use this to mimic window
        ' transparency.  (It's faster, and works more smoothly than attempting to use layered Windows, especially on XP.)
        Dim captureRect As RECTL
        GetWindowRect Me.hWnd, captureRect
        Screen_Capture.GetPartialDesktopAsDIB screenDIB, captureRect
        
        Dim formLeft As Long, formTop As Long, formWidth As Long, formHeight As Long
        formLeft = captureRect.Left
        formTop = captureRect.Top
        GetClientRect Me.hWnd, captureRect
        formWidth = captureRect.Right - captureRect.Left
        formHeight = captureRect.Bottom - captureRect.Top
        
        'Copy the screen background, shadow, and logo onto a single composite DIB
        Set splashDIB = New pdDIB
        splashDIB.CreateFromExistingDIB screenDIB
        shadowDIB.AlphaBlendToDC splashDIB.GetDIBDC, , FixDPI(1), FixDPI(1), formWidth, formWidth / logoAspectRatio
        logoDIB.AlphaBlendToDC splashDIB.GetDIBDC, , 0, 0, formWidth, formWidth / logoAspectRatio
        
        'Free all intermediate DIBs
        Set screenDIB = Nothing
        Set shadowDIB = Nothing
        Set logoDIB = Nothing
        
        'Next, we need to figure out where the top and bottom of the "PHOTODEMON" logo lie.  These values may change
        ' depending on the current screen DPI.  (Their position is important, because other text is laid out proportional
        ' to these values.)
        Dim pdLogoTop As Long, pdLogoBottom As Long, pdLogoRight As Long
        
        'FYI: the hard-coded values are for 96 DPI
        pdLogoTop = FixDPI(60)
        pdLogoBottom = FixDPI(125)
        pdLogoRight = FixDPI(755)
        
        'Next, we need to prepare a font renderer for displaying the current program version
        Set curFontVersion = New pdFont
        curFontVersion.SetFontBold True
        curFontVersion.SetFontSize 14
        
        'Non-production builds are tagged RED; normal builds, BLUE.  In the future, this may be tied to the theming engine.
        ' (It's not easy to do it at present, because the themer is loaded late in the program intialization process.)
        If PD_BUILD_QUALITY <> PD_PRODUCTION Then
            curFontVersion.SetFontColor RGB(255, 50, 50)
        Else
            curFontVersion.SetFontColor RGB(50, 127, 255)
        End If
        
        curFontVersion.CreateFontObject
        
        'Assemble the current version and description strings
        Dim versionString As String
        Dim versionWidth As Long, versionHeight As Long
        
        versionString = g_Language.TranslateMessage("version %1", GetPhotoDemonVersion)
        
        'Render the version string just below the logo text
        curFontVersion.AttachToDC splashDIB.GetDIBDC
        versionWidth = curFontVersion.GetWidthOfString(versionString)
        versionHeight = curFontVersion.GetHeightOfString(versionString)
        curFontVersion.FastRenderText pdLogoRight - versionWidth, pdLogoBottom + FixDPI(8), versionString
        curFontVersion.ReleaseFromDC
        
        'Copy the composite image onto the underlying form
        BitBlt Me.hDC, 0, 0, formWidth, formHeight, splashDIB.GetDIBDC, 0, 0, vbSrcCopy
        Me.Picture = Me.Image
        
    Else
        pdDebug.LogAction "WARNING!  Splash DIBs could not be loaded; something may be catastrophically wrong."
    End If
    
End Sub

'When the load function updates the current progress count, we refresh the splash screen to reflect the new progress.
Public Sub UpdateLoadProgress(ByVal newProgressMarker As Long)
    
    'If progress notifications arrived before the form was made visible, ignore them; this makes the loading bar appear
    ' more fluid, rather than magically jumping to the middle of the form when it's first loaded.
    If (m_ProgressAtFirstNotify = -1) Then m_ProgressAtFirstNotify = newProgressMarker - 1
    
    'Calculate the length of the progress line.  This is effectively arbitrary; I've made it the length of the
    ' logo image minus 10% for now.
    Dim lineLength As Long, lineOffset As Long
    lineLength = splashDIB.GetDIBWidth * 0.9
    lineOffset = (splashDIB.GetDIBWidth - lineLength) \ 2
    
    'Draw the current progress, if relevant
    If (m_MaxProgress > 0) And Me.Visible Then
    
        'Copy the splash DIB to overwrite any old drawing
        BitBlt Me.hDC, 0, 0, splashDIB.GetDIBWidth, splashDIB.GetDIBHeight, splashDIB.GetDIBDC, 0, 0, vbSrcCopy
        
        'Draw the progress line using GDI+
        Dim lineRadius As Long, lineY As Long
        lineRadius = FixDPI(6)
        lineY = splashDIB.GetDIBHeight - FixDPI(2) - lineRadius
        
        GDI_Plus.GDIPlusDrawLineToDC Me.hDC, lineOffset, lineY, (splashDIB.GetDIBWidth - lineOffset) * ((newProgressMarker - m_ProgressAtFirstNotify) / (m_MaxProgress - m_ProgressAtFirstNotify)), lineY, g_Themer.GetGenericUIColor(UI_Accent), 255, lineRadius, True, GP_LC_Round
        
        'Manually refresh the form
        Me.Picture = Me.Image
        Me.Refresh
    
    End If

End Sub

