module GtkUtils where

import Control.Applicative
import Control.Monad
import Data.IORef
import Data.Maybe

import qualified Graphics.UI.Gtk as G
import Graphics.UI.Gtk (AttrOp (..) -- for :=
                       ,on
                       )
import qualified Graphics.Rendering.Cairo as C
import qualified Graphics.UI.Gtk.Gdk.EventM as E
import Graphics.Rendering.Cairo (liftIO)

import Graphics.Declarative.Form

import Automaton

import KeyboardInput


data GtkEvent = Expose
              | KeyPress KeyboardInput
              deriving (Show)


type GtkFRP = Automaton (Event GtkEvent) (Behavior Form)


runGTK :: GtkFRP -> IO ()
runGTK automaton = gtkBoilerplate $ \canvas -> do
  automatonRef <- newIORef automaton

  let frpProcessEvent :: Maybe GtkEvent -> E.EventM any ()
      frpProcessEvent (Just frpEvent) = liftIO $ do
        automaton <- readIORef automatonRef
        let (newAutomaton, formBehavior) = stepEvent automaton frpEvent
        writeIORef automatonRef newAutomaton
        putStrLn $ "Got event " ++ show frpEvent
        renderForm canvas (behaviorValue formBehavior)
      frpProcessEvent Nothing = return ()

      processEvent :: E.EventM i (Maybe GtkEvent) -> E.EventM i Bool
      processEvent f = f >>= frpProcessEvent >> E.eventSent

  canvas `on` G.exposeEvent   $ processEvent handleExpose
  canvas `on` G.keyPressEvent $ processEvent handleKeyPress


handleExpose :: E.EventM E.EExpose (Maybe GtkEvent)
handleExpose = return (Just Expose)


handleKeyPress :: E.EventM E.EKey (Maybe GtkEvent)
handleKeyPress = do
  key <- E.eventKeyVal
  return $ KeyPress <$> keyboardInputFromGdk key


drawForm :: Form -> Double -> Double -> C.Render ()
drawForm form w h = do
  fDraw $ moved (w / 2, h / 2) $ centered $ form


renderForm :: G.WidgetClass w => w -> Form -> IO ()
renderForm canvas form = renderDoubleBuffered canvas (drawForm form)



--- GTK boilerplate ---
gtkBoilerplate f = do
  G.initGUI

  window <- G.windowNew
  screen <- G.windowGetScreen window
  w <- G.screenGetWidth screen
  h <- G.screenGetHeight screen
  G.set window [G.windowDefaultWidth   := (ceiling $ 0.7 * fromIntegral w)
               ,G.windowDefaultHeight  := (ceiling $ 0.7 * fromIntegral h)
               ,G.windowWindowPosition := G.WinPosCenter
               ]

  canvas <- G.drawingAreaNew
  G.containerAdd window canvas

  G.set canvas [G.widgetCanFocus := True]
  G.widgetModifyBg canvas G.StateNormal white
  G.widgetShowAll window

  G.onDestroy window G.mainQuit

  f canvas

  G.mainGUI 


white = G.Color 65535 65535 65535


render :: G.WidgetClass w => w -> (Double -> Double -> C.Render ()) -> IO ()
render canvas renderF = do
  (w, h) <- G.widgetGetSize canvas
  drawWin <- G.widgetGetDrawWindow canvas
  G.renderWithDrawable drawWin (renderF (fromIntegral w) (fromIntegral h))


renderDoubleBuffered canvas renderF = render canvas renderF'
  where
    renderF' w h = do
      C.pushGroup
      delete w h 
      renderF w h
      C.popGroupToSource
      C.paint

    delete w h = do
      C.setSourceRGB 1 1 1
      C.rectangle 0 0 w h
      C.fill
