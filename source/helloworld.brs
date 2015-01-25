'*************************************************************
'** HomeStream
'*************************************************************

Sub Main()
  ' Initializing Theme
  initTheme()

  ' Has to live for the duration of the whole app to prevent flashing
  ' back to the roku home screen.
  screenFacade = CreateObject("roPosterScreen")
  screenFacade.show()

  showFileScreen([],"")

  ' Exit the app gently so that the screen doesn't flash to black
  screenFacade.showMessage("Loading...")
  sleep(25)
End Sub

'*************************************************************
'** Theme
'*************************************************************

Function initTheme() as Void
  app = CreateObject("roAppManager")
  theme = CreateObject("roAssociativeArray")

  theme.OverhangPrimaryLogoOffsetSD_X = "72"
  theme.OverhangPrimaryLogoOffsetSD_Y = "15"
  theme.OverhangSliceSD = "pkg:/images/Overhang_BackgroundSlice_SD43.png"
  theme.OverhangPrimaryLogoSD  = "pkg:/images/Logo_Overhang_SD43.png"

  theme.OverhangPrimaryLogoOffsetHD_X = "123"
  theme.OverhangPrimaryLogoOffsetHD_Y = "10"
  theme.OverhangSliceHD = "pkg:/images/Overhang_BackgroundSlice_HD.png"
  theme.OverhangPrimaryLogoHD  = "pkg:/images/Logo_Overhang_HD.png"

  theme.SubtitleColor = "#f5f1e8"
  theme.BackgroundColor = "#000000"
  theme.ListItemText = "#7c7c7c"
  theme.ListItemHighlightText = "#CCCCCC"
  theme.BreadcrumbTextLeft = "#CCCCCC"
  theme.BreadcrumbTextRight = "#CCCCCC"
  
  app.SetTheme(theme)
End Function

'*************************************************************
'** Data
'*************************************************************

Function getFiles(folders as Object) as Object
  folderPath = ""

  for each folder in folders
    folderPath = folderPath + "/" + HttpEncode(folder)
  end for

  request = CreateObject("roUrlTransfer")
  port = CreateObject("roMessagePort")
  request.SetMessagePort(port)
  request.SetUrl("http://192.168.1.156:46005/api/videos" + folderPath)
  if (request.AsyncGetToString())
    while (true)
      msg = wait(0, port)
      if (type(msg) = "roUrlEvent")
        code = msg.GetResponseCode()
        if (code = 200)
          fileList = CreateObject("roArray", 10, true)
          json = ParseJSON(msg.GetString())
          for each file in json
            print file
            fileList.push(file)
          end for
          return fileList
        endif
      else if (event = invalid)
        request.AsyncCancel()
      endif
    end while
  endif
  return invalid
End Function

Function InitContentList(fileList as Object) as Object
  contentList = []

  for each file in fileList
    tempFile =   {
      Title: file,
      ID: "1"
    }

    if (right(file, 4) = ".mp4")
      tempFile.SDSmallIconUrl = "pkg:/images/video_small_sd.png"
      tempFile.HDSmallIconUrl = "pkg:/images/video_small_hd.png"
    else if (right(file, 4) = ".m4v")
      tempFile.SDSmallIconUrl = "pkg:/images/video_small_sd.png"
      tempFile.HDSmallIconUrl = "pkg:/images/video_small_hd.png"
    else
      tempFile.SDSmallIconUrl = "pkg:/images/folder_small_sd.png"
      tempFile.HDSmallIconUrl = "pkg:/images/folder_small_hd.png"
    endif

    contentList.push(tempFile)
  end for

  return contentList
End Function

'*************************************************************
'** showFileScreen(Object, String)
'*************************************************************

Function showFileScreen(folders as Object, selectedItem as String) as Integer
  fileList = getFiles(folders)

  screen = CreateObject("roListScreen")
  port = CreateObject("roMessagePort")
  screen.SetMessagePort(port)
  screen.SetHeader("Library")
  screen.SetBreadcrumbText("HomeStream", selectedItem)
  
  contentList = InitContentList(fileList)
  screen.SetContent(contentList)
  screen.show()
  
  while (true)
    msg = wait(0, port)
    if (type(msg) = "roListScreenEvent")
      if (msg.isListItemFocused())
        screen.SetBreadcrumbText("HomeStream", contentList[msg.GetIndex()].Title)
      else if (msg.isListItemSelected())
        if (right(contentList[msg.GetIndex()].Title, 4) = ".mp4")
          displayVideo(folders, contentList[msg.GetIndex()].Title)
        else if(right(contentList[msg.GetIndex()].Title, 4) = ".m4v")
          displayVideo(folders, contentList[msg.GetIndex()].Title)
        else
          folders.push(contentList[msg.GetIndex()].Title)
          showFileScreen(folders, contentList[msg.GetIndex()].Title)
        endif
      else if (msg.isScreenClosed())
        folders.pop()
        return -1
      endif            
    endif
  end while
End Function

'*************************************************************
'** displayVideo(Object, String)
'*************************************************************

Function displayVideo(folders as Object, videoFile as String) as Void
  print "Displaying video: " + videoFile

  folderPath = ""

  for each folder in folders
    folderPath = folderPath + "/" + HttpEncode(folder)
  end for

  p = CreateObject("roMessagePort")
  video = CreateObject("roVideoScreen")
  video.setMessagePort(p)

  theVideo = "http://192.168.1.156:46005/videos" + folderPath + "/" + HttpEncode(videoFile)

  print theVideo

  ' Video playback options
  urls = [theVideo]
  bitrates  = [0]    
  qualities = ["HD"]
  StreamFormat = "mp4"
  title = videoFile
  
  videoclip = CreateObject("roAssociativeArray")
  videoclip.StreamBitrates = bitrates
  videoclip.StreamUrls = urls
  videoclip.StreamQualities = qualities
  videoclip.StreamFormat = StreamFormat
  videoclip.Title = title
  
  video.SetContent(videoclip)
  video.show()

  lastSavedPos   = 0
  statusInterval = 10 ' position must change by more than this number of seconds before saving

  while true
    msg = wait(0, video.GetMessagePort())
    if type(msg) = "roVideoScreenEvent"
      if msg.isScreenClosed() then 'ScreenClosed event
        print "Closing video screen"
        exit while
      else if msg.isPlaybackPosition() then
        nowpos = msg.GetIndex()
        if nowpos > 10000
            
        end if
        if nowpos > 0
          if abs(nowpos - lastSavedPos) > statusInterval
            lastSavedPos = nowpos
          end if
        end if
      else if msg.isRequestFailed()
        print "play failed: "; msg.GetMessage()
      else
        print "Unknown event: "; msg.GetType(); " msg: "; msg.GetMessage()
      endif
    end if
  end while
End Function

'*************************************************************
'** Utils
'*************************************************************

Function HttpEncode(str As String) As String
  o = CreateObject("roUrlTransfer")
  return o.Escape(str)
End Function