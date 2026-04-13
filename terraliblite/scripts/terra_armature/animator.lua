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
    local autoTransitions = {}
    for k,v in next, animationsConfig do
        v.name = k
        if v.autoTransitions then
            v.transitions = v.transitions or {}
            for to,ti in next, v.autoTransitions do
                local o = animationsConfig[to]
                local startStance = v.stance or v.stances[#v.stances]
                local endStance = o.stance or o.stances[1]
                local name = string.format("auto_%sto%s",k,to)
                local anim = {
                    name=name,
                    stances={
                        startStance,
                        endStance
                    },
                    frameTime=ti,
                    transitionTo=to
                }
                autoTransitions[name] = anim
                v.transitions[to] = name
            end
        end
    end
    for k,v in next, autoTransitions do
        animationsConfig[k] = v
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
        currentAnimation=nil,
        animationTimer = 0,
        animationFrame = 1,
        sounds=true,
        stance = {},
        stanceLastInterp = true
    }
    setmetatable(out,stanceAnimatorMT)
    return out
end
-- setting animation to nil freezes the animator at the last stance
function stanceAnimator.setAnimation(self,a,f)
    if not a and not self.currentAnimation then
        return
    end
    if self.currentAnimation then
        if self.currentAnimation.name == a or (self.currentAnimation.transitionTo == a and not f) then
            return
        end
        if a then
            local transCheckAnim = self.currentAnimation
            if self.currentAnimation.transitionTo then -- if this is a transition, check that animation for further transitions instead.
                transCheckAnim = animationsConfig[self.currentAnimation.transitionTo]
            end
            if transCheckAnim.transitions and transCheckAnim.transitions[a] then
                self.currentAnimation = animationsConfig[transCheckAnim.transitions[a]]
            else
                self.currentAnimation = animationsConfig[a]
            end
        else
            self.currentAnimation = nil
        end
        if self.currentAnimation.sounds and self.sounds then
            playAnimationSound(self.currentAnimation.sounds[1])
        end
        if self.currentAnimation.animStates then
            local s = self.currentAnimation.animStates[1]
            if s then
                animator.setAnimationState(s[1],s[2])
            end
        end
    else
        self.currentAnimation = animationsConfig[a]
    end
    self.animationTimer = 0
    self.animationFrame = 1
end
function stanceAnimator.getDebug(self)
    return self.currentAnimation and self.currentAnimation.name or "nil"
end
function stanceAnimator.updateAnimation(self,dt)
    if not self.currentAnimation then
        return
    end
    if self.currentAnimation.stances then
        local nextFrame = self.animationFrame + 1
        local prevFrame = self.animationFrame - 1
        local animEnd = false
        if nextFrame > #self.currentAnimation.stances then
            if self.currentAnimation.loop then
                nextFrame = 1
            else
                nextFrame = self.animationFrame
            end
        end
        if prevFrame < 1 then
            if self.currentAnimation.loop then
                prevFrame = #self.currentAnimation.stances
            else
                prevFrame = self.animationFrame
            end
        end
        local speedScale = 1
        if self.currentAnimation.speedScaleReference and self.currentAnimation.speedScaleReference ~= 0 then
            -- find horizontal velocity
            local parent = world.entity(self.speedScaleEntity or animator_speedScaleEntity or entity.id())
            local boundBox = parent:boundBox()
            if parent:type() == "vehicle" then
                -- boundBox doesn't work with vehicles
                -- for now, assume same master and just use callScript to get it instead
                boundBox = parent:callScript("mcontroller.boundBox")
            end
            local refVel = refVelocity(parent:position(),vec2.add(parent:position(),{0,boundBox[2]-1}))
            local relVel = vec2.sub(parent:velocity(),refVel)
            if self.currentAnimation.speedScaleReverse then
                speedScale = facing*relVel[1]/self.currentAnimation.speedScaleReference
            else
                speedScale = math.abs(relVel[1])/self.currentAnimation.speedScaleReference
            end
        end
        self.animationTimer = self.animationTimer + dt*speedScale
        if self.animationTimer > self.currentAnimation.frameTime then
            self.animationTimer = self.animationTimer - self.currentAnimation.frameTime
            self.animationFrame = nextFrame
            if self.currentAnimation.sounds and self.sounds then
                playAnimationSound(self.currentAnimation.sounds[self.animationFrame])
            end
            if self.currentAnimation.animStates then
                local s = self.currentAnimation.animStates[self.animationFrame]
                if s then
                    animator.setAnimationState(s[1],s[2])
                end
            end
            nextFrame = self.animationFrame + 1
            if nextFrame > #self.currentAnimation.stances then
                if self.currentAnimation.loop then
                    nextFrame = 1
                else
                    nextFrame = self.animationFrame
                end
            end
        elseif self.animationTimer < 0 then
            -- move backwards
            self.animationTimer = self.animationTimer + self.currentAnimation.frameTime
            self.animationFrame = prevFrame
            nextFrame = self.animationFrame + 1
            if nextFrame > #self.currentAnimation.stances then
                if self.currentAnimation.loop then
                    nextFrame = 1
                else
                    nextFrame = self.animationFrame
                end
            end
            if self.currentAnimation.sounds and self.sounds then
                playAnimationSound(self.currentAnimation.sounds[nextFrame])
            end
            if self.currentAnimation.animStates then
                local s = self.currentAnimation.animStates[nextFrame]
                if s then
                    animator.setAnimationState(s[1],s[2])
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
