require "/scripts/terra_armature/armature.lua"
require "/scripts/terra_armature/stances.lua"
require "/scripts/terra_armature/animator_relVelocity.lua"

animator_speedScaleEntity = nil
local animationsConfig
local function processParenting(animation)
    if animation.parent then
        processParenting(animationsConfig[animation.parent])
        local parent = animationsConfig[animation.parent]
        animationsConfig[animation.name] = sb.jsonMerge(parent,animation)
        animationsConfig[animation.name].parent = nil
    end
end
function initAnimation()
    animationsConfig = config.getParameter("skelAnimation")
    for k,v in next, animationsConfig do
        v.name = k
    end
    for k,v in next, animationsConfig do
        processParenting(v)
    end
end
function playAnimationSound(s)
    if s then
        if type(s) == "table" then
            for _,so in next, s do
                animator.playSound(so)
            end
        else
            animator.playSound(s)
        end
    end
end
local stanceAnimator = {}
local stanceAnimatorMT = {__index=stanceAnimator}
function buildAnimator()
    local out = {
        currentAnimation=animationsConfig.idle,
        animationTimer = 0,
        animationFrame = 1,
        sounds=true,
        stance = {},
        stanceLastInterp = true
    }
    setmetatable(out,stanceAnimatorMT)
    return out
end
function stanceAnimator.setAnimation(self,a,f)
    if self.currentAnimation.name == a or (self.currentAnimation.transitionTo == a and not f) then
        return
    end
    if self.currentAnimation.transitions and self.currentAnimation.transitions[a] then
        self.currentAnimation = animationsConfig[self.currentAnimation.transitions[a]]
    else
        self.currentAnimation = animationsConfig[a]
    end
    if self.currentAnimation.sounds and self.sounds then
        playAnimationSound(self.currentAnimation.sounds[1])
    end
    self.animationTimer = 0
    self.animationFrame = 1
end
function stanceAnimator.getDebug(self)
    return self.currentAnimation.name
end
function stanceAnimator.updateAnimation(self,dt)
    if self.currentAnimation.stances then
        local nextFrame = self.animationFrame + 1
        local animEnd = false
        if nextFrame > #self.currentAnimation.stances then
            if self.currentAnimation.loop then
                nextFrame = 1
            else
                nextFrame = self.animationFrame
            end
        end
        local speedScale = 1
        if self.currentAnimation.speedScaleReference and self.currentAnimation.speedScaleReference ~= 0 then
            -- find horizontal velocity
            local parent = world.entity(self.speedScaleEntity or animator_speedScaleEntity or entity.id())
            local refVel = refVelocity(parent:position(),vec2.add(parent:position(),{0,parent:boundBox()[2]-1}))
            local relVel = vec2.sub(parent:velocity(),refVel)
            speedScale = math.abs(relVel[1])/self.currentAnimation.speedScaleReference
        end
        self.animationTimer = self.animationTimer + dt*speedScale
        if self.animationTimer > self.currentAnimation.frameTime then
            self.animationTimer = self.animationTimer - self.currentAnimation.frameTime
            self.animationFrame = nextFrame
            if self.currentAnimation.sounds and self.sounds then
                playAnimationSound(self.currentAnimation.sounds[self.animationFrame])
            end
            nextFrame = self.animationFrame + 1
            if nextFrame > #self.currentAnimation.stances then
                if self.currentAnimation.loop then
                    nextFrame = 1
                else
                    nextFrame = self.animationFrame
                end
            end
        end
        local perc = self.animationTimer/self.currentAnimation.frameTime
        self.stance = stanceInterpolated(
            stances[self.currentAnimation.stances[nextFrame]],
            stances[self.currentAnimation.stances[self.animationFrame]],
            perc,
            self.stanceLastInterp and self.stance or {}
        )
        self.stanceLastInterp = true
        if self.animationFrame == #self.currentAnimation.stances and self.currentAnimation.transitionTo then
            self:setAnimation(self.currentAnimation.transitionTo,true)
        end
    elseif self.currentAnimation.stance then
        self.stance = stances[self.currentAnimation.stance]
        self.stanceLastInterp = false
    end -- if neither case is fulfilled... why?
end
