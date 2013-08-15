package weave.ui
{
	import flash.display.DisplayObject;
	import flash.events.Event;
	import flash.events.KeyboardEvent;
	import flash.events.MouseEvent;
	import flash.geom.Point;
	import flash.text.StyleSheet;
	import flash.ui.Keyboard;
	import flash.utils.Dictionary;
	import flash.utils.getQualifiedClassName;
	
	import mx.controls.Alert;
	import mx.core.BitmapAsset;
	import mx.core.IFactory;
	import mx.core.IVisualElementContainer;
	import mx.core.SpriteAsset;
	import mx.core.UIComponent;
	import mx.events.CloseEvent;
	import mx.events.DragEvent;
	import mx.events.FlexEvent;
	import mx.events.ResizeEvent;
	import mx.managers.PopUpManager;
	
	import spark.components.Button;
	import spark.components.Group;
	import spark.components.HGroup;
	import spark.components.Image;
	import spark.components.Label;
	import spark.components.Panel;
	import spark.components.ToggleButton;
	import spark.components.supportClasses.ButtonBase;
	
	import weave.Weave;
	import weave.api.WeaveAPI;
	import weave.api.getCallbackCollection;
	import weave.api.getLinkableOwner;
	import weave.api.newDisposableChild;
	import weave.api.newLinkableChild;
	import weave.api.registerDisposableChild;
	import weave.api.registerLinkableChild;
	import weave.api.reportError;
	import weave.api.core.IDisposableObject;
	import weave.api.core.ILinkableHashMap;
	import weave.api.core.ILinkableObject;
	import weave.compiler.StandardLib;
	import weave.core.LinkableBoolean;
	import weave.core.LinkableFunction;
	import weave.core.LinkableNumber;
	import weave.core.LinkableString;
	import weave.ui.controlBars.VisTaskbar;
	import weave.ui.skins.DraggablePanelSkin;
	import weave.utils.CustomCursorManager;
	import weave.utils.EditorManager;
	import weave.utils.NumberUtils;
	
	
	
	public class DraggablePanel extends Panel implements ILinkableObject,IDisposableObject
	{
		public function DraggablePanel()
		{
			super();
			this.setStyle("skinClass" , Class(DraggablePanelSkin));
			styleName="weave-panel-style";
			
			this.addEventListener(FlexEvent.PREINITIALIZE,preinitialize);
			this.addEventListener(Event.ADDED_TO_STAGE,handleAddedToStage);
			this.addEventListener(Event.REMOVED_FROM_STAGE,handleRemovedFromStage);			
			this.addEventListener(MouseEvent.ROLL_OVER,handleMouseRollOver);
			this.addEventListener(MouseEvent.ROLL_OUT,handleMouseRollOut);
			this.addEventListener(ResizeEvent.RESIZE,handleResize);	
			this.addEventListener(MouseEvent.MOUSE_DOWN, handleMouseDown, true);			
		}
		
		
		
		[SkinPart(required="true")]
		public var titleBar:Group;
		
		[SkinPart(required="true")]
		public var titleBarControlsHolder:Group;
		
		
		[SkinPart(required="true")]
		public var titleSettingsHolder:HGroup;
		
		[SkinPart(required="false")]
		public var controlBar:Group;
		
		
		
		
		
		
		//A dynamic skin part that defines userControlButton button
		[SkinPart(required="true",type="spark.components.Button")]
		public var userControlButtonFactory:IFactory;
		
		private var userControlButton:Button;
		
		//A dynamic skin part that defines userControlButton button
		[SkinPart(required="true",type="spark.components.Button")]
		public var subMenuButtonFactory:IFactory;
		
		
		private var subMenuButton:Button;
		
		
		
		
		[SkinPart(required="true")]
		public var minimizeButton:Button;
		
		[SkinPart(required="true")]
		public var maximizeButton:ToggleButton;
		
		[SkinPart(required="true")]
		public var closePanelButton:Button;
		
		[SkinPart(required="true")]
		public var pinButton:Button;
		
		[SkinPart(required="true")]
		public var pinToBackButton:Button;
		
		
		
		
		
		//raw children replacement
		[SkinPart(required="true")]
		public var dragCanvas:Group;
		
		[SkinPart(required="true")]
		public var moveImage:Image;
		
		[SkinPart(required="true")]
		public var busyIndicator:BusyIndicator;		
		
		
		[Embed(source="/weave/resources/images/tinyWrench2.png")]
		private var _userControlIcon:Class; 
		[Embed(source="/weave/resources/images/arrowDown.png")]
		private var _subMenuIcon:Class;
		
		[Embed(source="/weave/resources/images/resize_TB.png")]
		private var _resizeTBCursor:Class;
		private var _resizeTBBitmap:BitmapAsset = new _resizeTBCursor() as BitmapAsset;
		[Embed(source="/weave/resources/images/resize_LR.png")]
		private var _resizeLRCursor:Class;
		private var _resizeLRBitmap:BitmapAsset = new _resizeLRCursor() as BitmapAsset;
		[Embed(source="/weave/resources/images/resize_TL-BR.png")]
		private var _resizeTLBRCursor:Class;
		private var _resizeTLBRBitmap:BitmapAsset = new _resizeTLBRCursor() as BitmapAsset;
		[Embed(source="/weave/resources/images/resize_TR-BL.png")]
		private var _resizeTRBLCursor:Class;
		private var _resizeTRBLBitmap:BitmapAsset = new _resizeTRBLCursor() as BitmapAsset;
		
		private var draggablePanelCursorID:int = -1;
		
		protected var subMenu:SubMenu;
		
		
		
		public static var adminMode:Boolean = false;
		public static var activePanel:DraggablePanel = null;
		
		public static function get activePanelName():String
		{
			return Weave.root.getName(activePanel);
		}
		
		public static function getTopPanel():DraggablePanel
		{
			return Weave.root.getObjects(DraggablePanel).pop();
		}
		
		/**
		 * panelX, panelY, panelWidth, panelHeight
		 * These are sessioned strings that can be either absolute coordinates or percentages.
		 */
		public const panelX:LinkableString      = registerLinkableChild(this, new LinkableString('' + int(20 + Math.random() * 10) + "%", NumberUtils.verifyNumberOrPercentage));
		public const panelY:LinkableString      = registerLinkableChild(this, new LinkableString('' + int(20 + Math.random() * 10) + "%", NumberUtils.verifyNumberOrPercentage));
		public const panelWidth:LinkableString  = registerLinkableChild(this, new LinkableString("50%", NumberUtils.verifyNumberOrPercentage));
		public const panelHeight:LinkableString = registerLinkableChild(this, new LinkableString("50%", NumberUtils.verifyNumberOrPercentage));
		
		public const maximized:LinkableBoolean = registerLinkableChild(this, new LinkableBoolean(false, verifyMaximized),handleMaximizedChange,true);
		public const minimized:LinkableBoolean = registerLinkableChild(this, new LinkableBoolean(false, verifyMinimized),handleMinimizedChange,true);
		public const pinned:LinkableBoolean	   = registerLinkableChild(this, new LinkableBoolean(false),handlePinnedChange,true);
		public const pinnedToBack:LinkableBoolean = registerLinkableChild(this, new LinkableBoolean(false), handlePinnedToBackChange, true);
		
		public const panelTitle:LinkableString = newLinkableChild(this, LinkableString, handlePanelTitleChange);
		
		public const enableMoveResize:LinkableBoolean = registerLinkableChild(this, new LinkableBoolean(true), panelNeedsUpdate, true);
		public const enableSubMenu:LinkableBoolean    = registerLinkableChild(this, new LinkableBoolean(false));
		public const minimizable:LinkableBoolean      = registerLinkableChild(this, new LinkableBoolean(true), panelNeedsUpdate, true);
		public const maximizable:LinkableBoolean      = registerLinkableChild(this, new LinkableBoolean(true), panelNeedsUpdate, true);
		public const pinnable:LinkableBoolean         = registerLinkableChild(this, new LinkableBoolean(true), panelNeedsUpdate, true);
		public const pinnableToBack:LinkableBoolean   = registerLinkableChild(this, new LinkableBoolean(false), panelNeedsUpdate, true);
		public const closeable:LinkableBoolean        = registerLinkableChild(this, new LinkableBoolean(true), panelNeedsUpdate, true); 
		public const enableBorders:LinkableBoolean    = registerLinkableChild(this, new LinkableBoolean(true), panelNeedsUpdate, true);
		
		public const panelBorderColor:LinkableNumber = registerLinkableChild( this, new LinkableNumber(NaN), handleBorderColorChange, true);
		public const panelBackgroundColor:LinkableNumber = registerLinkableChild( this, new LinkableNumber(NaN), handleBackgroundColorChange, true);
		public const buttonRadius:LinkableNumber = registerLinkableChild(this, new LinkableNumber(3), panelNeedsUpdate, true);
		//callback function moved to skin
		public const panelStyleList:LinkableString = newLinkableChild(this, LinkableString);
		
		private function verifyMinimized(value:Boolean):Boolean { return !minimizable || minimizable.value || !value; }
		private function verifyMaximized(value:Boolean):Boolean { return !maximizable || maximizable.value || !value; }
		
		
		/**
		 *  This method is called when a UIComponent is constructed,
		 *  and again whenever the ResourceManager dispatches
		 *  a <code>"change"</code> Event to indicate
		 *  that the localized resources have changed in some way.
		 */
		override protected function resourcesChanged():void
		{
			super.resourcesChanged();
			if (!_constructorCalled) // avoid calling constructor twice
			{
				_constructorCalled = true;
				constructor();
			}
		}
		private var _constructorCalled:Boolean = false; // true when constructor has been called
		
		/**
		 * A constructor cannot be defined in MXML.
		 * This function gets called as a result of calling the super class's constructor.
		 * Classes that extend DraggablePanel can override this and call super.constructor().
		 * Any code that should execute in the constructor can be put into this function.
		 * This function should not be called directly.
		 */
		protected function constructor():void
		{
			//trace(this,"constructor");
			
			// use capture phase on mouse down event because otherwise, if the panel is a popup,
			// drop-down menus will be hidden behind the window after we move the window to the front.			
			
			panelX.addImmediateCallback(this, function():void { copyCoordinatesFromSessionedProperties(panelX); });
			panelY.addImmediateCallback(this, function():void { copyCoordinatesFromSessionedProperties(panelY); });
			panelWidth.addImmediateCallback(this, function():void { copyCoordinatesFromSessionedProperties(panelWidth); });
			panelHeight.addImmediateCallback(this, function():void { copyCoordinatesFromSessionedProperties(panelHeight); });
			
			getCallbackCollection(Weave.properties.panelTitleTextFormat).addGroupedCallback(this, handleTitleTextFormatChange, true);
			Weave.properties.dashboardMode.addGroupedCallback(this, panelNeedsUpdate);
			Weave.properties.enableToolControls.addGroupedCallback(this, panelNeedsUpdate, true);
			getCallbackCollection(Weave.root).addGroupedCallback(this, evaluatePanelTitle);
		}
		
		/**
		 * This function gets called when the preinitialize event is dispatched.
		 * Subclasses can override this method and call super.preinitialize().
		 */
		protected function preinitialize(e:FlexEvent = null):void{
			// nothing here, just a placeholder
			
		} 
		
				
		override protected function createChildren():void
		{
			
			
			super.createChildren();
			createDynamicSkinParts();
			
			// These calls to setStyle fix the display bug where there is a ~200 px bottom margin and ~20 px right margin.
			var pad:int = 0;
			
			setStyle("paddingLeft", pad);
			setStyle("paddingRight", pad);
			setStyle("paddingBottom", pad);
			setStyle("paddingTop", pad);
			
			setupControlButton(userControlButton, _userControlIcon, toggleControlPanel, "Click here to change settings for this component.");			
			setupControlButton(subMenuButton, _subMenuIcon, null, "Click here to open menu items for this component.");
			setupControlButton(pinToBackButton, null, togglePinnedToBack, "Click here to pin this window to the back of the stage");
			setupControlButton(pinButton, null, togglePinned, "Click here to pin this window to the stage.") ;
			setupControlButton(minimizeButton, null, handleMinimizeButtonClick, "Click here to minimize this component.");
			setupControlButton(maximizeButton, null, toggleMaximized, "Click here to maximize or restore this component.");
			setupControlButton(closePanelButton, null, handleCloseButtonClick, "Click here to close this component.");
			
			
			
			// if the draggable panel is simplevistool
			// controlpanel will be part of MXML
			// remove them and add as disposablechild to simplevistool
			for (var i:int = 0; i < numElements; i++)
			{
				if (getElementAt(i) is ControlPanel)
				{
					_controlPanel = registerDisposableChild(this, getElementAt(i) as ControlPanel);
					removeElement(_controlPanel);
					break;
				}
			}
			
			if (!_controlPanel && EditorManager.getEditorClass(this))
			{
				_controlPanel = newDisposableChild(this, ControlPanel);
				var editor:UIComponent = EditorManager.getNewEditor(this) as UIComponent;
				addElement(_controlPanel);
				removeElement(_controlPanel);
				_controlPanel.tabNavigator.addElement(editor);
			}
			
			if (_controlPanel)
				_controlPanel.title = "Settings for " + getQualifiedClassName(this).split("::")[1];
			
			
			
			moveImage.addEventListener(MouseEvent.MOUSE_DOWN, handleTitleBarMouseDown);
			moveImage.addEventListener(MouseEvent.DOUBLE_CLICK, function(e:Event):void { toggleControlPanel(); });
			
			titleBar.doubleClickEnabled = true;
			titleBar.addEventListener(MouseEvent.MOUSE_DOWN, handleTitleBarMouseDown);
			titleBar.addEventListener(MouseEvent.DOUBLE_CLICK, handleTitleBarDoubleClick);
			
			minWidth = 24;
			
			
			addEventListener(DragEvent.DRAG_ENTER, handleDragEnter, true);
			addEventListener(DragEvent.DRAG_ENTER, handleDragEnter);
			
			(titleDisplay as Label).setStyle("color", Weave.properties.panelTitleTextFormat.color.value);
			
			panelNeedsUpdate();
			
		}
		
		
		override protected function childrenCreated():void
		{
			super.childrenCreated();
			panelNeedsUpdate();
		}
		
		override protected function partAdded(partName:String, instance:Object):void
		{
			super.partAdded(partName, instance);				
			if (partName == "userControlButtonFactory")
			{					
				setupControlButton(Button(instance), _userControlIcon, toggleControlPanel, "Click here to change settings for this component.");				
			}
			if (partName == "subMenuButtonFactory")
			{		
				setupControlButton(Button(instance), _subMenuIcon, null, "Click here to open menu items for this component.");				
			}
			
		}
		
		
		private function createDynamicSkinParts():void{
		
			userControlButton = createDynamicPartInstance("userControlButtonFactory") as Button;
			subMenuButton = createDynamicPartInstance("subMenuButtonFactory") as Button;
			subMenu = new SubMenu(subMenuButton,[MouseEvent.CLICK, MouseEvent.DOUBLE_CLICK]);
		}
		
		/**
		 * Override this function to provide a default panel title when the panelTitle session state is undefined.
		 * The panel title will be set when handlePanelTitleChange() is called.
		 * If you need the panel title to be updated, you can call handlePanelTitleChange() directly or as a callback.
		 */
		protected function get defaultPanelTitle():String
		{
			return getQualifiedClassName(this).split(':').pop();
		}
		
		/**
		 * This gets called when the panelTitle session state changes.
		 * If you need the panel title to be updated, you can call this function directly or as a callback.
		 * If you need to override the default panel title, override the "get defaultPanelTitle" accessor function.
		 */
		protected function handlePanelTitleChange():void
		{
			if (panelTitle.value)
			{
				panelTitleFunction.value = '`' + panelTitle.value.split('`').join('\\`') + '`';
				// title will be automatically updated by grouped callback
			}
			else
			{
				title = defaultPanelTitle;
			}
		}
		private const panelTitleFunction:LinkableFunction = registerDisposableChild(this, new LinkableFunction(null, true, true)); // this is used in handlePanelTitleChange()
		
		// this gets called as a grouped callback when Weave.root changes and whenever panelTitle can be compiled to a function
		private function evaluatePanelTitle():void
		{
			try
			{
				if (panelTitle.value)
					title = panelTitleFunction.apply(this);
			}
			catch (e:Error)
			{
				//reportError(e);
				title = panelTitle.value;
			}
		}
		
		private function handleTitleTextFormatChange():void
		{
			if (titleDisplay)
				Weave.properties.panelTitleTextFormat.copyToStyle(titleDisplay as Label);
		}
		
		[Bindable] public var sessionPanelCoordsAsPercentages:Boolean = true;
		
		// this metadata tag allows you to specify a percentage value like x="25%" in MXML.
		[PercentProxy("percentX")]
		override public function set x(value:Number):void
		{
			super.x = Math.round(value);
		}
		// this metadata tag allows you to specify a percentage value like y="25%" in MXML.
		[PercentProxy("percentY")]
		override public function set y(value:Number):void
		{
			super.y = Math.round(value);
		}
		
		//			[PercentProxy("percentWidth")]
		//			override public function set width(value:Number):void
		//			{
		//				super.width = Math.round(value);
		//			}
		//			[PercentProxy("percentHeight")]
		//			override public function set height(value:Number):void
		//			{
		//				super.height = Math.round(value);
		//			}
		
		[Inspectable(environment="none")]
		public function set percentX(value:Number):void
		{
			panelX.value = "" + value + "%";
		}
		[Inspectable(environment="none")]
		public function set percentY(value:Number):void
		{
			panelY.value = "" + value + "%";
		}
		
		
		
		override public function set percentWidth(value:Number):void
		{
			panelWidth.value = "" + value + "%";
		}
		override public function set percentHeight(value:Number):void
		{
			panelHeight.value = "" + value + "%";
		}
		
		
		private function get realParent():DisplayObject{
			var realParent:DisplayObject;
			if(parentDocument is DraggablePanelSkin)
				realParent = (parentDocument as DraggablePanelSkin).skinOwner as DisplayObject;
			else
				realParent = parent as DisplayObject;
			return realParent;
		}
		
		private function handleAddedToStage(event:Event):void
		{
			stage.addEventListener(MouseEvent.MOUSE_MOVE, handleStageMouseMove);
			stage.addEventListener(MouseEvent.MOUSE_UP, handleStageMouseUp);
			parent.addEventListener(ResizeEvent.RESIZE, handleParentResize);
			
			copyCoordinatesFromSessionedProperties();
		}
		private function handleRemovedFromStage(event:Event):void
		{
			stage.removeEventListener(MouseEvent.MOUSE_MOVE, handleStageMouseMove);
			stage.removeEventListener(MouseEvent.MOUSE_UP, handleStageMouseUp);
			parent.removeEventListener(ResizeEvent.RESIZE, handleParentResize);
		}
		
		
		/**
		 * This function copies the values for x,y,width,height from the corresponding sessioned properties.
		 * @param singleProperty Set this to one of panelX,panelY,panelWidth,panelHeight to only update that property.
		 */
		private function copyCoordinatesFromSessionedProperties(singleProperty:LinkableString = null):void
		{
			if (!parent)
				return;
			var originalParent:DisplayObject = realParent;
			
			if (!singleProperty || singleProperty == panelX)
				copyCoordinateFromLinkableString(panelX, originalParent.width, "x");
			if (!singleProperty || singleProperty == panelY)
				copyCoordinateFromLinkableString(panelY, originalParent.height, "y");
			if (!singleProperty || singleProperty == panelWidth)
				copyCoordinateFromLinkableString(panelWidth, originalParent.width, "width", minWidth);
			if (!singleProperty || singleProperty == panelHeight)
				copyCoordinateFromLinkableString(panelHeight, originalParent.height, "height", minHeight);
			callLater(fixHeight);
		}
		private function fixHeight():void
		{
			if (!parent)
				return;
			var originalParent:DisplayObject = realParent;
			
			if (y + height > originalParent.height) // rounding error, reproduceable when parent height is 625
				height = originalParent.height - y;
		}
		// watch(this,"{ [panelX.value,panelY.value,panelWidth.value,panelHeight.value] }\r{ [x,y,width,height] }")
		
		private static const _maximizedCoordinates:Object = {x: "0%", y: "0%", width: "100%", height: "100%"};
		
		/**
		 * This function will copy a sessioned string like "75%" as a Number using the calculation "part = whole * percent / 100".
		 * If the sessioned string does not have a "%" sign in it, it will be treated as an absolute coordinate.
		 * @param part The LinkableString contianing the "part" value to use in the calculation.
		 * @param whole The "whole" value in the calculation (parent width or height).
		 * @param destinationPropertyName The name of a property to set on this object (x, y, width, or height) which is the "part" value.
		 */
		private function copyCoordinateFromLinkableString(part:LinkableString, whole:Number, destinationPropertyName:String, minValue:Number = NaN):void
		{
			if (parent == null)
				return;
			
			var numberOrPercent:String = part.value;
			
			// if maximized, use maximized coordinates
			if (maximized.value)
				numberOrPercent = _maximizedCoordinates[destinationPropertyName];
			
			var result:Number = NumberUtils.getNumberFromNumberOrPercent(numberOrPercent, whole);
			
			//trace("handleAbsoluteAndPercentageValues",arguments,numberOrPercent,whole,result);
			if (isFinite(result))
			{
				if (isFinite(minValue))
					result = Math.max(minValue, result);
				this[destinationPropertyName] = result;
			}
		}
		
		private function panelNeedsUpdate():void
		{
			if (!parent)
				return;
			
			// disable highlight when borders are disabled (avoids display bug when corners are rounded)
			setStyle('highlightAlphas', enableBorders.value ? undefined : [0,0]);
			
			_enableMoveResize = (!Weave.properties.dashboardMode.value && enableMoveResize.value) || adminMode;
			if (!enableMoveResize.value && _enableMoveResize)
				moveImage.alpha = 0.1;
			else
				moveImage.alpha = 0.25;
			
			if (!maximizable.value)
				maximized.value = false;
			if (!minimizable.value)
				minimized.value = false;
			if (!pinnable.value)
				pinned.value = false;
			if (!pinnableToBack.value)
				pinnedToBack.value = false;
			
			
			invalidateSize();
			invalidateDisplayList();
			updateBorders();
		}
		
		override public function move(x:Number, y:Number):void
		{
			super.move(Math.round(x), Math.round(y));
		}
		
		/**
		 * This function constrains x,y,width,height so that this DraggablePanel is contained in its parent,
		 * then it saves the coordinates (absolute or percentage) to the sessioned properties.
		 */
		protected function constrainAndSaveCoordinates():void
		{
			// don't copy coordinates while tool is minimized or maximized
			if (!parent || minimized.value || maximized.value)
				return;
			
			// init local vars
			var originalParent:DisplayObject = realParent;
			var _x:Number = x;
			var _y:Number = y;
			var _right:Number = x + width;
			var _bottom:Number = y + height;
			var _parentWidth:Number = originalParent.width;
			var _parentHeight:Number = originalParent.height;
			
			// calculate snap size
			var snapStr:String = Weave.properties.windowSnapGridSize.value;
			var usePercent:Boolean = (Weave.properties.enablePanelCoordsPercentageMode.value && sessionPanelCoordsAsPercentages);
			var snapNum:Number = StandardLib.asNumber(snapStr.replace('%', ''));
			
			// adjust snap to match panel coordinate mode
			if (usePercent != (snapStr.indexOf('%') >= 0))
			{
				if (usePercent)
					snapNum = 100 * snapNum / Math.max(_parentWidth, _parentHeight);
				else
					snapNum = Math.round(Math.max(_parentWidth, _parentHeight) * snapNum / 100)
			}
			if ((usePercent && snapNum <= 0) || (!usePercent && snapNum < 1))
				snapNum = 1;
			
			// convert numbers to percentages if necessary
			if (usePercent)
			{
				_x = 100 * _x / _parentWidth;
				_y = 100 * _y / _parentHeight;
				_right = 100 * _right / _parentWidth;
				_bottom = 100 * _bottom / _parentHeight;
				_parentWidth = 100;
				_parentHeight = 100;
			}
			// truncate width,height
			_parentWidth = Math.floor(_parentWidth / snapNum) * snapNum;
			_parentHeight = Math.floor(_parentHeight / snapNum) * snapNum;
			
			// snap coordinates to grid
			_x = Math.round(_x / snapNum) * snapNum;
			_y = Math.round(_y / snapNum) * snapNum;
			var _width:Number = Math.round(_right / snapNum) * snapNum - _x;
			var _height:Number = Math.round(_bottom / snapNum) * snapNum - _y;
			
			// constrain width,height before x,y because the x,y constrain code depends on width,height
			_width = Math.round(StandardLib.constrain(_width, 0, _parentWidth));
			_height = Math.round(StandardLib.constrain(_height, 0, _parentHeight));
			_x = Math.round(StandardLib.constrain(_x, 0, _parentWidth - _width));
			_y = Math.round(StandardLib.constrain(_y, 0, _parentHeight - _height));
			
			// copy the x,y,width,height coordinates to the corresponding sessioned properties.
			var str:String = usePercent ? '%' : '';
			panelWidth.value = _width + str;
			panelHeight.value = _height + str;
			panelX.value = _x + str;
			panelY.value = _y + str;
			copyCoordinatesFromSessionedProperties();
		}
		
		[Inspectable] protected var controlBarWidthBeforeScale:int = -1;
		//    		[Inspectable] protected var minWidthBeforeScale:int = -1;
		//    		[Inspectable] protected var minHeightBeforeScale:int = -1;
		
		private function handleResize(event:ResizeEvent):void
		{
			if (!parent)
				return;
			
			if (_dragging || _resizing)
				constrainAndSaveCoordinates();
			
			if (controlBar && controlBarWidthBeforeScale > 0)
			{
				controlBar.scaleX = controlBar.scaleY = (width < controlBarWidthBeforeScale) ? (width / controlBarWidthBeforeScale) : 1;
			}
			
			//    			scaleX = width < minWidthBeforeScale ? width / minWidthBeforeScale : 1.0;
			//    			scaleY = height < minHeightBeforeScale ? height / minHeightBeforeScale : 1.0;
		}
		
		public function updateBorders():void
		{
			if (!parent)
				return;
			
			styleChanged("headerHeight");
			notifyStyleChangeInChildren("headerHeight", true);
			updateMoveIcon();
			invalidateDisplayList();
		}
		
		private function updateMoveIcon():void
		{
			//the moveImage will be enabled if the enableMoveIcon is enabled and the panel is moveable and headerHeight is zero.
			moveImage.visible = _enableMoveResize && !borderIsVisible && (adminMode || !Weave.properties.dashboardMode.value);
		}
		
		public function get borderIsVisible():Boolean
		{
			return enableBorders.value && !Weave.properties.dashboardMode.value;
		}
		
		
		
		
		
		/**
		 * The parameter to this function is a generic Event to avoid crashing when parent is systemManager.
		 * If we make the type ResizeEvent, we may get the error "Cannot convert Event to ResizeEvent".
		 */
		private function handleParentResize(event:Event):void
		{
			if (Weave.properties.enablePanelCoordsPercentageMode.value && sessionPanelCoordsAsPercentages)
				copyCoordinatesFromSessionedProperties();
		}
		
		private function handleCloseAlertResult(event:CloseEvent):void
		{			
			if (event.detail == Alert.YES)
			{
				removePanel();
			}
			// no need to do anything else for the other options, in those cases we dont want to close the window so do nothing
		}
		
		public function togglePinned():void
		{
			pinned.value = !pinned.value ;
			pinnedToBack.value = false;
			
		}
		public function togglePinnedToBack():void
		{
			pinnedToBack.value = !pinnedToBack.value;
			pinned.value = false;
		}
		
		
		
		private function handlePinnedChange():void
		{
			if (!pinnableToBack.value)
				pinnedToBack.value = false;
			if (pinnedToBack.value)
				pinButton.setStyle("fillColors",[_titleBarButtonSelectedColor,_titleBarButtonSelectedColor]);
			else
				pinButton.setStyle("fillColors",[_titleBarButtonBackgroundColor, _titleBarButtonBackgroundColor] );	
			updatePinnedPanelOrder();
			
			
			
		}
		
		private function handlePinnedToBackChange():void
		{
			if (!pinnableToBack.value)
				pinnedToBack.value = false;
			if (pinnedToBack.value)
				pinToBackButton.setStyle("fillColors",[_titleBarButtonSelectedColor,_titleBarButtonSelectedColor]);
			else
				pinToBackButton.setStyle("fillColors",[_titleBarButtonBackgroundColor, _titleBarButtonBackgroundColor] );
			updatePinnedPanelOrder();
		}
		
		
		
		
		public function toggleMaximized():void
		{
			// toggle maximized state
			maximized.value = !maximized.value;
		}
		
		
		
		
		
		private function handleBorderColorChange():void
		{	
			
			updateBorders();
		}
		
		private function handleBackgroundColorChange():void
		{
			
			updateBorders();
		}
		
		private function handleCloseButtonClick():void
		{
		if (Weave.properties.showVisToolCloseDialog.value)
			Alert.show("Are you sure you want to close this window?", "Closing this window...", 1|2, this, handleCloseAlertResult);
		else
			removePanel();
		} 
		
		
		
		
		public function removePanel():void
		{
			var panels:Array = [this, _controlPanel];
			DraggablePanel.activePanel = null;
			for each (var panel:DraggablePanel in panels)
			{
				if (!panel)
					continue;
				try
				{
					// un-maximize
					panel.maximized.value = false;
					if (panel && panel.parent){
						if(panel.parent is IVisualElementContainer){
							(panel.parent as IVisualElementContainer).removeElement(panel);
						}
						else{							
							panel.parent.removeChild(panel);
						}
					}
				}
				catch (e:Error)
				{
					reportError(e);
				}
			}
		}
		
		private var _initialTitleBarMouseDownPoint:Point = new Point(0,0);
		
		private var _rightSideResize:Boolean = false;
		private var _leftSideResize:Boolean = false;
		private var _topSideResize:Boolean = false;
		private var _bottomResize:Boolean = false;
		private var _resizing:Boolean = false;
		private var _dragging:Boolean = false;
		
		private var _enableMoveResize:Boolean = false; // used internally to remember whether or not the panel is actually moveable
		
		private var _rightSideBeforeLeftResize:int = 0;
		private var _bottomSideBeforeTopResize:int = 0;
		
		private function handleMouseDown(event:MouseEvent):void
		{
			if (!_enableMoveResize)
				return;
			
			if (!parent)
				return;
			
			_leftSideResize = false;
			_rightSideResize = false;
			_topSideResize = false;
			_bottomResize = false;
			
			var childIndex:Number;
			var lastElementIndex:int;
			if(parent is IVisualElementContainer){
				childIndex = (parent as IVisualElementContainer).getElementIndex(this);
				lastElementIndex = (parent as IVisualElementContainer).numElements -1;
			}
			else {
				childIndex = parent.getChildIndex(this);
				lastElementIndex = parent.numChildren-1;
			}
			// bring panel to front
			if (childIndex< lastElementIndex)
				sendWindowToForeground();
			
			
			if (!minimized.value && !maximized.value)
			{
				var status:Object = getResizeStatus(stage.mouseX, stage.mouseY);
				
				if (status.R)
					_rightSideResize = true;
				else if (status.L)
				{
					_rightSideBeforeLeftResize = this.x + this.width;
					_leftSideResize = true;
				}
				
				
				if (status.B)
					_bottomResize = true;
				else if (status.T)
				{
					_bottomSideBeforeTopResize = this.y + this.height;
					_topSideResize = true;
				}
				
				if (status.resizing)
				{
					_resizing = true;
					event.stopImmediatePropagation();
				}
				else
					_resizing = false;
			}
		}
		
		public static const resizeBorderThickness:int = 5;
		private var tempPoint:Point = new Point();
		/**
		 * getResizeStatus
		 * Returns a set of Boolean values corresponding to which sides (top,left,bottom,right) should be resized.
		 * @param stageX The current stage X mouse coordinate.
		 * @param stageY The current stage Y mouse coordinate.
		 * @return An object containing the following properties: T,L,B,R,TL,TR,BL,BR,resizing
		 */
		private function getResizeStatus(stageX:Number, stageY:Number):Object
		{
			var o:Object = new Object();
			// not resizing when coordinates are outside the window
			if (!_mouseRolledOver){
				o.T = o.TL = o.L = o.BL = o.B = o.BR = o.R = o.TR = false;
			}
			else{
				tempPoint.x = mouseX;
				tempPoint.y = mouseY;
				var local:Point = tempPoint;
				// get side status values
				o.L = local.x < resizeBorderThickness;
				o.R = local.x > this.width - resizeBorderThickness;
				o.T = local.y < resizeBorderThickness;
				o.B = local.y > this.height - resizeBorderThickness;
				
				// get side status values for 4x the border thickness (to mimic Windows' corner resize behavior)
				var L4:Boolean = local.x < resizeBorderThickness * 4;
				var R4:Boolean = local.x > this.width - resizeBorderThickness * 4;
				var T4:Boolean = local.y < resizeBorderThickness * 4;
				var B4:Boolean = local.y > this.height - resizeBorderThickness * 4;
				// corner status is true if mouse is within a square of 4x the border thickness and at least one corresponding side status is true
				o.TL = (T4 && L4) && (o.T || o.L);
				o.TR = (T4 && R4) && (o.T || o.R);
				o.BL = (B4 && L4) && (o.B || o.L);
				o.BR = (B4 && R4) && (o.B || o.R);
				// status for individual sides should be or'd with relevant corner status values
				o.T |= o.TL || o.TR;
				o.L |= o.TL || o.BL;
				o.B |= o.BL || o.BR;
				o.R |= o.TR || o.BR;
			}			
			
			// we are resizing if we are in the resize area for the top, left, bottom or right
			o.resizing = (o.T || o.L || o.B || o.R);
			
			return o;
		}
		
		// Keep track of the active panel (one that the user has their mouse over) for use in exporting a panel image in the context menu.
		// This is needed so that when the user right clicks on a panel, we know which panel they want to export an image of (cannot tell
		// it from the context menu event).  
		private var _mouseRolledOver:Boolean = false;
		private function handleMouseRollOver(event:MouseEvent):void
		{
			if (!parent)
				return;
			
			DraggablePanel.activePanel = this;
			_mouseRolledOver = true;
		}
		private function handleMouseRollOut(event:MouseEvent):void
		{
			_mouseRolledOver = false;
			
			if (!parent)
				return;
			DraggablePanel.activePanel = null;
			
			if (_enableMoveResize && !_resizing)
				CustomCursorManager.removeCursor(draggablePanelCursorID);
			
			if (_resizing)
				event.stopImmediatePropagation();
		}
		
		public function sendWindowToForeground():void
		{
			if (_enableMoveResize)
			{
				// put the name of this panel at the end of the hash map names so it appears in front
				var hashMap:ILinkableHashMap = getLinkableOwner(this) as ILinkableHashMap;
				if (hashMap)
					hashMap.setNameOrder([hashMap.getName(this)]);
				else if (parent){
					if(parent is IVisualElementContainer ){
						var visualParent:IVisualElementContainer = parent as IVisualElementContainer;
						visualParent.setElementIndex(this, visualParent.numElements - 1);
					}
					else{
						parent.setChildIndex(this, parent.numChildren - 1);
					}
				}
				
			}
			updatePinnedPanelOrder();
		}
		
		public function sendWindowToBackground():void
		{
			if (_enableMoveResize)
			{
				// put the name of this panel at the beginning of the hash map names so it appears in back
				var hashMap:ILinkableHashMap = getLinkableOwner(this) as ILinkableHashMap;
				if (hashMap)
				{
					var names:Array = hashMap.getNames();
					names.unshift(hashMap.getName(this));
					hashMap.setNameOrder(names);
				}
			}
			updatePinnedPanelOrder();
		}
		
		private function updatePinnedPanelOrder():void
		{
			var hashMap:ILinkableHashMap = getLinkableOwner(this) as ILinkableHashMap;
			if (hashMap)
			{
				var names:Array = hashMap.getNames();
				var back:Array = [];
				var front:Array = [];
				for (var i:int = 0; i < names.length; i++)
				{
					var name:String = names[i];
					var panel:DraggablePanel = hashMap.getObject(name) as DraggablePanel;
					if (panel)
					{
						if (panel.pinned.value)
						{
							front.push(name);
							names.splice(i--, 1);
						}
						else  if (panel.pinnedToBack.value)
						{
							back.push(name);
							names.splice(i--, 1);
						}
					}
				}
				hashMap.setNameOrder(back.concat(names).concat(front));
			}
		}
		
		private function handleTitleBarDoubleClick(event:MouseEvent):void
		{
			// do not allow double click on any of the control buttons
			if (event.target is Button)
				return;
			
			toggleMaximized();
		}
		private function handleTitleBarMouseDown(event:MouseEvent):void
		{
			if (!_enableMoveResize || maximized.value)
				return;
			
			if (!parent)
				return;
			
			sendWindowToForeground();
			updatePinnedPanelOrder();
			
			updateBorders();
			
			_initialTitleBarMouseDownPoint = globalToLocal(new Point(stage.mouseX, stage.mouseY));
			
			/*for each(var child:* in this.getChildren())
			child.cacheAsBitmap = true;*/
			
			if (getResizeStatus(stage.mouseX, stage.mouseY).resizing)
				_dragging = false;
			else
				_dragging = true;
			
			
			// we don't want to allow resizing or dragging if we are on any of the buttons
			if (event.target is Button || event.target is SpriteAsset)
			{
				_dragging = false;
				_resizing = false;
			}
		}
		
		private function handleStageMouseUp(event:MouseEvent):void
		{
			_dragging = false;
			_resizing = false;
			_leftSideResize = false;
			_rightSideResize = false;
			_topSideResize = false;
			_bottomResize = false;
		}
		private function handleStageMouseMove(event:MouseEvent):void
		{
	
			// make sure cursors dont keep changing while resizing:  !_resizing
			if (parent && !_resizing && !minimized.value && !maximized.value)
			{
				var status:Object = getResizeStatus(stage.mouseX, stage.mouseY);
				var resizeCursorName:String = null;
				// check to see if the mouse is in the top left (TL) or bottom right (BR) corner
				if (status.TL || status.BR)
					resizeCursorName = CURSOR_RESIZE_TOPLEFT_BOTTOMRIGHT;
					// check to see if the mouse is in the top right (TR) or bottom left (BL) corner
				else if (status.TR || status.BL)
					resizeCursorName = CURSOR_RESIZE_TOPRIGHT_BOTTOMLEFT;
					// check to see if the mouse is on the left or right side (LR)
				else if (status.L || status.R)
					resizeCursorName = CURSOR_RESIZE_LEFT_RIGHT;
					// check to see if the mouse is on the top or bottom side
				else if (status.T || status.B)
					resizeCursorName = CURSOR_RESIZE_TOP_BOTTOM;
				
				CustomCursorManager.removeCursor(draggablePanelCursorID);
				if ( resizeCursorName!= null && !event.buttonDown && _enableMoveResize)
				{
					try
					{
						draggablePanelCursorID = CustomCursorManager.showCursor(resizeCursorName);
					}
					catch (e:Error)
					{
						draggablePanelCursorID = -1;
						reportError(e);
					}
				}
			}
			
			if (_dragging || _resizing)
				event.stopImmediatePropagation();
			
			delayedHandleStageMouseMove();
		}
		
		private function delayedHandleStageMouseMove():void
		{
			// don't do anything if this panel is not added to the stage.
			if (!parent)
				return;
			var originalParent:DisplayObject = realParent;
			// delay this function while the mouse is still moving
			if (WeaveAPI.StageUtils.mouseMoved)
			{
				callLater(delayedHandleStageMouseMove);
				return;
			}
			
			if (!_enableMoveResize)
				return;
			
			var parentMousePoint:Point = new Point(originalParent.mouseX, originalParent.mouseY);
			
			if (_dragging)
			{
				// constrain the window X location to be between 0 and the right side of the window
				var newX:int = parentMousePoint.x - _initialTitleBarMouseDownPoint.x;
				// constrain the window Y location to be between 0 and the bottom of the window
				var newY:int = parentMousePoint.y - _initialTitleBarMouseDownPoint.y;
				this.move(newX, newY);
				constrainAndSaveCoordinates();
			}
			if (_resizing)
			{
				if (_rightSideResize)
				{
					this.width = StandardLib.constrain( (parentMousePoint.x - this.x), minWidth, (originalParent.width - this.x) );
				}
				else if (_leftSideResize)
				{
					this.x = StandardLib.constrain( (parentMousePoint.x), 0, _rightSideBeforeLeftResize - minWidth );
					this.width = (_rightSideBeforeLeftResize - this.x);
				}
				if (_bottomResize)
				{
					this.height = StandardLib.constrain( (parentMousePoint.y - this.y), minHeight, (originalParent.height - this.y) );
				}
				else if (_topSideResize)
				{
					this.y = StandardLib.constrain( (parentMousePoint.y), 0, _bottomSideBeforeTopResize - minHeight );
					this.height = (_bottomSideBeforeTopResize - this.y);
				}		
			}
		}
		private var _controlPanel:ControlPanel = null;
		
		public function get controlPanel():ControlPanel { return _controlPanel; }
		
		public function toggleControlPanel():void
		{
			if (_controlPanel)
			{
				if (!_controlPanel.parent)
					PopUpManager.addPopUp(_controlPanel, WeaveAPI.topLevelApplication as UIComponent);
				_controlPanel.sendWindowToForeground();
			}
			else
			{
				SessionStateEditor.openDefaultEditor(this);
			}
		}
		
		
		private var _titleBarButtonBackgroundColor:uint = 0xD0D0D0;
		private var _titleBarButtonSelectedColor:uint   = 0xFFFF80;
		private function setupControlButton(buttonBase:ButtonBase, icon:Class, clickHandler:Function, tooltip:String = null):void
		{			
			if(icon){
				buttonBase.setStyle("icon", icon);
			}				
			buttonBase.toolTip = tooltip;
			
			buttonBase.setStyle("fontFamily",    "Arial");
			buttonBase.setStyle("color", 0x000000);
			buttonBase.setStyle("paddingBottom", 1);
			buttonBase.setStyle("paddingLeft",   1);
			buttonBase.setStyle("paddingRight",  1);
			buttonBase.setStyle("paddingTop",    1);
			buttonBase.setStyle("fontSize",      12);
			buttonBase.setStyle("fontWeight",    "bold");
			buttonBase.setStyle("cornerRadius",  1);
			
			buttonBase.setStyle("fillAlphas", [1,1] );
			buttonBase.setStyle("fillColors", [_titleBarButtonBackgroundColor, _titleBarButtonBackgroundColor] );
			
			
			if(clickHandler != null)
			{
				var buttonListener:Function = function(e:MouseEvent):*
				{
					clickHandler();
					e.stopImmediatePropagation();
				};
				buttonBase.addEventListener(MouseEvent.CLICK, buttonListener);
			}
			buttonBase.width = buttonSize;
			buttonBase.height = buttonSize;
			//buttonBase.buttonMode = true;
		}
		//need to be public to access in the skin
		[Bindable]
		public var buttonSize:int = 17;	
		[Bindable]
		public var buttonOffsetFromSide:int = 5;	
		[Bindable]
		public var spaceBetweenButtons:Number = 2;
		
		public function getRightIconAreaWidth():int
		{
			// by default, width of icons is the border only
			var rightIconWidths:int = buttonOffsetFromSide;
			for each (var lb:LinkableBoolean in [closeable, minimizable, maximizable, pinnable, pinnableToBack])
			if (lb.value)
				rightIconWidths += buttonSize + spaceBetweenButtons;
			
			return rightIconWidths;
		}
		
		public function getTotalIconAreaWidth():int 
		{
			return getLeftIconAreaWidth() + getRightIconAreaWidth();
		} 
		
		private function getButtonOffsetFromSide():int 
		{
			return Math.max(buttonOffsetFromSide, Number(this.getStyle("cornerRadius")/2) );
		}
		
		private function getLeftIconAreaWidth():int
		{
			var leftIconWidths:int = getButtonOffsetFromSide();
			
			if (Weave.properties.enableToolControls.value && _controlPanel)
			leftIconWidths += buttonSize + spaceBetweenButtons;
			if(subMenuButton.visible)
			leftIconWidths += buttonSize + spaceBetweenButtons;
			
			return leftIconWidths;
		} 
		
		
		
		
		
		override protected function commitProperties():void
		{
			//minHeight = borderMetrics.top + borderMetrics.bottom;
			
			super.commitProperties();
		}
		
		
		private function updateButtons():void
		{
			// don't do anything if not added to a parent to avoid errors like the following:
			/*
			ArgumentError: Error #2004: One of the parameters is invalid.
			at flash.display::Graphics/drawRoundRect()
			at mx.skins::ProgrammaticSkin/drawRoundRect()[C:\autobuild\3.5.0\frameworks\projects\framework\src\mx\skins\ProgrammaticSkin.as:763]
			at mx.skins.halo::ButtonSkin/updateDisplayList()[C:\autobuild\3.5.0\frameworks\projects\framework\src\mx\skins\halo\ButtonSkin.as:217]
			at mx.skins::ProgrammaticSkin/validateDisplayList()[C:\autobuild\3.5.0\frameworks\projects\framework\src\mx\skins\ProgrammaticSkin.as:421]
			at mx.managers::LayoutManager/validateDisplayList()[C:\autobuild\3.5.0\frameworks\projects\framework\src\mx\managers\LayoutManager.as:622]
			at mx.managers::LayoutManager/doPhasedInstantiation()[C:\autobuild\3.5.0\frameworks\projects\framework\src\mx\managers\LayoutManager.as:695]
			at Function/http://adobe.com/AS3/2006/builtin::apply()
			at mx.core::UIComponent/callLaterDispatcher2()[C:\autobuild\3.5.0\frameworks\projects\framework\src\mx\core\UIComponent.as:8744]
			at mx.core::UIComponent/callLaterDispatcher()[C:\autobuild\3.5.0\frameworks\projects\framework\src\mx\core\UIComponent.as:8684]
			*/
			if(!parent)
			{
				callLater(updateButtons);
				return;
			}
			
			// we only need to update title, buttons if the height is > 0, otherwise do not show the buttons
			if (getStyle("headerHeight") <= 0)
			{
				userControlButton.visible = false;
				minimizeButton.visible    = false; 
				maximizeButton.visible    = false;
				pinButton.visible = false;
				subMenuButton.visible = false;
			}
			else
			{
				
				if ( Weave.properties.enableToolControls.value && _controlPanel )
				{
					if (titleBarControlsHolder != userControlButton.parent){							 
						titleSettingsHolder.addElementAt(userControlButton,0);
					}
					userControlButton.setStyle("cornerRadius",  buttonRadius.value);
					userControlButton.width  = buttonSize;
					userControlButton.height = buttonSize;
					
					userControlButton.visible = true;
				}
				else
				{	
					if(userControlButton)					
						userControlButton.visible = false;					
				}
				
				if (closeable.value)
				{
					closePanelButton.includeInLayout = true;
					closePanelButton.visible = true;
				}
				else
				{
					closePanelButton.includeInLayout = false;
					closePanelButton.visible = false;
				}
				if (maximizable.value)
				{
					maximizeButton.includeInLayout = true;
					maximizeButton.visible = true;
				}
				else
				{
					maximizeButton.includeInLayout = false;
					maximizeButton.visible = false;
				}
				
				if (minimizable.value)
				{					
					minimizeButton.includeInLayout = true;
					minimizeButton.visible = true;
				}
				else
				{
					minimizeButton.includeInLayout = false;
					minimizeButton.visible = false;
				}
				if (pinnable.value)
				{
					pinButton.includeInLayout = true;
					pinButton.visible = true;
				}
				else
				{
					pinButton.includeInLayout = false;
					pinButton.visible = false;
				}
				if (pinnableToBack.value)
				{
					pinToBackButton.includeInLayout = true;
					pinToBackButton.visible = true;
				}
				else
				{
					pinToBackButton.includeInLayout = false;
					pinToBackButton.visible = false;
				}
				
				if(enableSubMenu.value)
				{
					if (titleBar != subMenuButton.parent){
						if(userControlButton.visible){
							titleSettingsHolder.addElementAt(subMenuButton,1);
						}
						else{
							titleSettingsHolder.addElementAt(subMenuButton,0);							
						}
					}
					
					subMenuButton.setStyle("cornerRadius",  buttonRadius.value);
					subMenuButton.width  = buttonSize;
					subMenuButton.height = buttonSize;
					
					subMenuButton.visible = true;
				}
				else
				{
					if(subMenuButton)
						subMenuButton.visible = false;
				}
				
				
			}
		}
		
		
		override protected function updateDisplayList(unscaledWidth:Number, unscaledHeight:Number):void
		{
			// force pixel boundaries
			unscaledWidth = Math.round(unscaledWidth);
			unscaledHeight = Math.round(unscaledHeight);
			super.updateDisplayList(unscaledWidth, unscaledHeight);
			
			updateButtons();
			
			if (controlBar)
				controlBar.visible = !minimized.value;
			
			
		}
		
		private var minimizedComponentVersion:MinimizedComponent = null;
		protected function handleMinimizeButtonClick():void
		{
			var hashMap:ILinkableHashMap = getLinkableOwner(this) as ILinkableHashMap;
			if (WeaveAPI.StageUtils.shiftKey && hashMap)
			{
				for each (var panel:DraggablePanel in hashMap.getObjects(DraggablePanel))
				panel.minimizePanel();
			}
			else
			{
				minimizePanel();
			}
		}
		
		private function handleMaximizedChange():void
		{
			if(!maximizeButton){
				callLater(handleMaximizedChange);
				return;
			}
			
			copyCoordinatesFromSessionedProperties();
			if (maximized.value)
				maximizeButton.selected = true;
			else
				maximizeButton.selected = false;
		}
		
		private function handleMinimizedChange():void
		{
			if (minimized.value) // minimize
			{
				enabled = visible = false;
				if (!minimizedComponentVersion)
					minimizedComponentVersion = VisTaskbar.instance.addMinimizedComponent(this, restorePanel);
			}
			else // restore
			{
				enabled = visible = true;
				if (minimizedComponentVersion)
					VisTaskbar.instance.removeMinimizedComponent(minimizedComponentVersion);
				minimizedComponentVersion = null;
				copyCoordinatesFromSessionedProperties();
				
				// this fixes the display bugs that occurs when restoring a minimized window
				updateBorders();
			}
		}
		
		
		
		public function minimizePanel():void
		{
			if (_controlPanel)
				_controlPanel.removePanel();
			minimized.value = true;
		}
		
		public function restorePanel():void
		{
			sendWindowToForeground();
			minimized.value = false;
		}
		
		
		/**
		 * This will be called when this object is no longer needed.
		 * Classes that extend this class should override this function and call super.dispose().
		 */
		public function dispose():void
		{
			if (minimizedComponentVersion)
				VisTaskbar.instance.removeMinimizedComponent(minimizedComponentVersion);
			minimizedComponentVersion = null;
			
			removeEventListener(MouseEvent.MOUSE_DOWN, handleMouseDown, true);
			removeEventListener(DragEvent.DRAG_ENTER, handleDragEnter, true);
			removeEventListener(DragEvent.DRAG_ENTER, handleDragEnter);
			
			if (titleBar != null)
			{
				titleBar.removeEventListener(MouseEvent.MOUSE_DOWN, handleTitleBarMouseDown);
				titleBar.removeEventListener(MouseEvent.DOUBLE_CLICK, handleTitleBarDoubleClick);
			}
		}
		
		private function handleDragEnter(event:DragEvent):void
		{
			restorePanel();
		}
		
		
		/**
		 * This function will create and reuse a static instance of each type of DraggablePanel requested.
		 * @param classDef A Class extending DraggablePanel.
		 */
		public static function openStaticInstance(draggablePanelClass:Class):DraggablePanel
		{
			var instance:DraggablePanel = _instances[draggablePanelClass];
			if (!instance)
			{
				_instances[draggablePanelClass] = instance = new draggablePanelClass() as DraggablePanel;
				instance.pinnable.value = false;
				instance.pinnableToBack.value = false;
			}
			if (!instance.parent)
				PopUpManager.addPopUp(instance, WeaveAPI.topLevelApplication as UIComponent);
			instance.restorePanel();
			
			return instance;
		}
		private static const _instances:Dictionary = new Dictionary();
		
		
		private var _escapeKeyClosesPanel:Boolean = false;
		
		public function get escapeKeyClosesPanel():Boolean
		{
			return _escapeKeyClosesPanel;
		}
		
		/**
		 * Set this to true to allow the ESCAPE key to close this panel.
		 */
		public function set escapeKeyClosesPanel(value:Boolean):void
		{
			_escapeKeyClosesPanel = value;
			if (value)
				WeaveAPI.StageUtils.addEventCallback(KeyboardEvent.KEY_DOWN, this, handleKeyDown);
			else
				WeaveAPI.StageUtils.removeEventCallback(KeyboardEvent.KEY_DOWN, handleKeyDown);
		}
		
		private function handleKeyDown():void
		{
			var event:KeyboardEvent = WeaveAPI.StageUtils.keyboardEvent;
			if (parent && event && event.keyCode == Keyboard.ESCAPE)
			{
				// find the top-most draggable panel with escapeKeyClosesPanel=true
				for (var i:int = (parent as IVisualElementContainer).numElements; i--;)
				{
					var panel:DraggablePanel = (parent as IVisualElementContainer).getElementAt(i) as DraggablePanel;
					if (panel && panel.escapeKeyClosesPanel)
					{
						if (panel == this)
						{
							stage.focus = parent;
							panel.handleEscapeKey();
						}
						// we don't want to do anything more
						return;
					}
				}
			}
		}
		
		/**
		 * This function gets called when the user presses ESCAPE and escapeKeyClosesPanel has been set to true.
		 */
		protected function handleEscapeKey():void
		{
			// don't remove immediately because we don't want multiple windows to close in handleKeyDown()
			callLater(removePanel);
		}

		
		/**
		 * Embedded cursors
		 */
		public static const CURSOR_RESIZE_TOP_BOTTOM:String = "resizeTopBottom";
		[Embed(source="/weave/resources/images/resize_TB.png")]
		private static var resizeTBCursor:Class;
		CustomCursorManager.registerEmbeddedCursor(CURSOR_RESIZE_TOP_BOTTOM, resizeTBCursor, NaN, NaN);
		
		public static const CURSOR_RESIZE_LEFT_RIGHT:String = "resizeLeftRight";
		[Embed(source="/weave/resources/images/resize_LR.png")]
		private static var resizeLRCursor:Class;
		CustomCursorManager.registerEmbeddedCursor(CURSOR_RESIZE_LEFT_RIGHT, resizeLRCursor, NaN, NaN);
		
		public static const CURSOR_RESIZE_TOPLEFT_BOTTOMRIGHT:String = "resizeTLBR";
		[Embed(source="/weave/resources/images/resize_TL-BR.png")]
		private static var resizeTLBRCursor:Class;
		CustomCursorManager.registerEmbeddedCursor(CURSOR_RESIZE_TOPLEFT_BOTTOMRIGHT, resizeTLBRCursor, NaN, NaN);
		
		public static const CURSOR_RESIZE_TOPRIGHT_BOTTOMLEFT:String = "resizeTRBL";
		[Embed(source="/weave/resources/images/resize_TR-BL.png")]
		private static var resizeTRBLCursor:Class;
		CustomCursorManager.registerEmbeddedCursor(CURSOR_RESIZE_TOPRIGHT_BOTTOMLEFT, resizeTRBLCursor, NaN, NaN);
		
	
		[Deprecated(replacement="panelTitle")] public function set toolTitle(value:String):void { panelTitle.value = value; }
		[Deprecated(replacement="enableBorders")] public function set hideBorders(value:Boolean):void { enableBorders.value = !value; }
		[Deprecated(replacement="enableMoveResize")] public function set draggable(value:Boolean):void { enableMoveResize.value = value; }
		[Deprecated(replacement="enableMoveResize")] public function set resizeable(value:Boolean):void { enableMoveResize.value = value; }
		
		
		
		
		
		
		
	}
}