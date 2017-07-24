config = {}
config['py_lib_dir']  = 'H:\\Libraries\\Anaconda\\Lib\\'      # where we find the Python libraries
config['save_dir']    = 'D:/playing-for-data/data/processed/' # where we store extraction results
# creates a prefixes for files and directories from logfilename
config['dir_prefix']  = lambda logFilename : ''       
config['file_prefix'] = lambda logFilename : basename(logFilename)[:-4] + '_'

# The following values depend on the game and need to be specified.
# Hence, we do not set default values.
# For extracting mesh, shader, and texture ids we need to reliably identify the G-buffer pass.
# By 'G-buffer' pass we mean the pass that renders all objects of interest. Hence, this pass will reference
# all meshes, shaders, and textures.
# We identify the G-buffer pass by its render targets (number of color targets, whether there is depth)
# If multiple passes fulfil the specified conditions, we only process the first one. 
# You need to change this behaviour for some games.
config['gbufferpass_colortargets'] = None # number of color targets that identify the G-buffer pass, most probably 4 as games want to use all available render targets
config['gbufferpass_hasdepth']     = None # whether G-buffer pass has a depth target
# Our names for the color buffers
config['gbuffer_names']            = ['gbuffer1', 'gbuffer2'] # the number should match the config['gbufferpass_colortargets']
# We want to extract clean images without any UI elements. Hence, we need to identify the pass
# where the HUD is rendered.
config['hudpass_colortargets'] = None # number of color targets that identify the HUD pass
config['hudpass_hasdepth']     = None # whether HUD pass has a depth target
config['hudpass_drawcallname'] = '' # name of drawcall event

# Add python libraries
import sys
sys.path.append(config['py_lib_dir'])

# Load frame info
frameInfo = renderdoc.FrameInfo
assert(len(frameInfo) == 1, 'expected only one frame.')
frameId   = renderdoc.CurFrame
print 'Extracting from frame %d' % frameId

# Get prefix and set up directory
from os import mkdir
from os.path import dirname, basename, exists
dirPrefix  = config['dir_prefix'](renderdoc.LogFileName)
filePrefix = config['file_prefix'](renderdoc.LogFileName)
saveDir    = '%s/%s/' % (config['save_dir'], dirPrefix)
if not exists(saveDir):
	mkdir(saveDir)
	pass
print 'Output directory is %s' % saveDir
print 'File prefix is %s' % filePrefix

# Get drawcalls
drawcalls = renderdoc.GetDrawcalls(frameId)
print 'Found %d drawcalls.' % len(drawcalls)

def containsTargets(drawcallName, numColorTargets, hasDepthTarget):
	""" Determines if drawcall has multiple render targets by checking its name. 
	    The name is defined by renderdoc and contains information about render targets."""	
	if hasDepthTarget:
		return drawcallName.find('(%d Targets + Depth)' % numColorTargets) >= 0		
	else:		
		return drawcallName.find('(%d Targets)' % numColorTargets) >= 0		
	pass

def findGbufferPass(numColorTargets, hasDepthTarget):
	""" Identifies the G-buffer pass. """
	gbufferEnd = 0
	gbufferIds = [i for i,call in enumerate(drawcalls) if containsTargets(call.name, numColorTargets, hasDepthTarget)]
	if len(gbufferIds) == 1:
		gbufferId    = gbufferIds[0]
		gbufferCalls = drawcalls[gbufferId].children
		print 'G-buffer pass has %d drawcalls.' % len(gbufferCalls)
		gbufferEnd   = drawcalls[gbufferId].children[-1].eventID # last drawcall of the G-buffer pass
		pass
	
	assert(gbufferEnd > 0, 'Did not find any drawcall with the specified G-buffer settings.')
	return gbufferId, gbufferEnd
	
def findFinalPass(numColorTargets, hasDepthTarget, drawCallName):
	""" Returns the EventID of the pass that draws the final image (before HUD). """

	# Find last drawcall before HUD
	potentialHudIds = [i for i,call in enumerate(drawcalls) if containsTargets(call.name, numColorTargets, hasDepthTarget)]
	print 'Found %d potential HUD passes.' % len(potentialHudIds)

	colorpassIds = [i for i,call in enumerate(drawcalls) if containsTargets(call.name, 1, False)]

	a = colorpassIds[:]
	a.extend(potentialHudIds[:-3])
	assert(len(a) > 0, 'Found not enough potential final passes.')
	firstPotentialFinalId = max(a)

	finalPassId = 0
	return [call.eventID for call in drawcalls[-1:0:-1] if call.name.find(drawCallName) >= 0][1]
	
def getColorBuffers(frameId, eventId):
	""" Sets the pipeline to eventId and returns the ids of bound render targets. """
	renderdoc.SetEventID(None, frameId, eventId)
	commonState   = renderdoc.CurPipelineState
	outputTargets = commonState.GetOutputTargets()
	return [t for t in outputTargets if str(t) <> '0']

def initIDRendering(frameId, gbufferId, gbufferEnd):
	""" Initializes ID rendering. """
	gbufferStart = drawcalls[gbufferId].children[0].eventID
	renderdoc.SetEventID(None, frameId, gbufferStart)
	renderdoc.SetIDRenderingEvents(frameId, gbufferStart, gbufferEnd)
	renderdoc.SetIDRendering(True)
	pass

	
gbufferId, gbufferEnd = findGbufferPass(config['gbufferpass_colortargets'], config['gbufferpass_hasdepth'])
print 'G-buffer pass is done at EID %d.' % gbufferEnd
bufferIds = getColorBuffers(frameId, gbufferEnd)

# Save color targets
for i,bid in enumerate(bufferIds):
 	renderdoc.SaveTexture(bid, '{0}/{1}_{2}.png'.format(saveDir, filePrefix, config['gbuffer_names'][i]))

# Save depth target
depthTarget = renderdoc.CurPipelineState.GetDepthTarget()
renderdoc.SaveTexture(depthTarget, '{0}/{1}_depth.exr'.format(saveDir, filePrefix))

finalPassId = findFinalPass(config['hudpass_colortargets'], config['hudpass_hasdepth'], config['hudpass_drawcallname'])
assert(finalPassId == 0, 'Found not enough potential final passes.')

bufferIds = getColorBuffers(frameId, finalPassId)
assert(len(bufferIds) == 1, 'Found %d potential final render targets.' % len(bufferIds))
renderdoc.SaveTexture(bufferIds[0], '{0}/{1}_final.png'.format(saveDir, filePrefix))

# now do the id rendering
print 'Rendering ids...',
initIDRendering(frameId, gbufferId, gbufferEnd)
bufferIds   = getColorBuffers(frameId, gbufferEnd)
bufferNames = ['texture', 'mesh', 'shader', 'overflow']

for i,bid in enumerate(bufferIds):
	renderdoc.SaveTexture(bid, '{0}/{1}_{2}.png'.format(saveDir, filePrefix, bufferNames[i]))

renderdoc.HashTextures('{0}/{1}_tex.txt'.format(saveDir, filePrefix))
renderdoc.HashBuffers('{0}/{1}_mesh.txt'.format(saveDir, filePrefix))
renderdoc.HashShaders('{0}/{1}_shader.txt'.format(saveDir, filePrefix))

print 'done.'

# close renderdoc
#renderdoc.AppWindow.Close()

