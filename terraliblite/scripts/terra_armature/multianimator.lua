require "/scripts/terra_armature/armature.lua"
require "/scripts/terra_armature/stances.lua"

local multiStanceAnimator = {}
local multiStanceAnimatorMT = {__index=multiStanceAnimator}
function buildMultiAnimator(config,animators)
    local out = {
        currentAnimator=config.defaultAnimator,
        nextAnimator=config.defaultAnimator,
        animators=animators,
        transitionTimer=0,
        transitionTime=0,
        sounds=true,
        config=config,
        stance = {},
        stanceLastInterp = true
    }
    setmetatable(out,multiStanceAnimatorMT)
    return out
end
function multiStanceAnimator.setAnimator(self,a)
    if self.nextAnimator == a then
        return
    end
    self.currentAnimator = self.nextAnimator
    self.nextAnimator = a
    self.transitionTimer = 0
    local t = self.config.transitionTimes and self.config.transitionTimes[self.currentAnimator]
    self.transitionTime = (t and t[a]) or self.config.baseTransitionTime or 0
end
function multiStanceAnimator.getDebug(self)
    return self.currentAnimator.."\n"..self.animators[self.currentAnimator]:getDebug()
end
function multiStanceAnimator.updateAnimation(self,dt)
    for k,v in next,self.animators do
        if k == self.nextAnimator then
            v.sounds = self.sounds
        else
            v.sounds = false
        end
        v:updateAnimation(dt)
    end
    if self.transitionTimer < self.transitionTime then
        self.transitionTimer = self.transitionTimer + dt
        local perc
        if self.transitionTimer >= self.transitionTime then
            self.transitionTimer = 0
            self.transitionTime = 0
            self.currentAnimator = self.nextAnimator
            perc = 0
        else
            perc = self.transitionTimer/self.transitionTime
        end
        self.stance = stanceInterpolated(
            self.animators[self.nextAnimator].stance,
            self.animators[self.currentAnimator].stance,
            perc,
            self.stanceLastInterp and self.stance or {}
        )
        self.stanceLastInterp = true
    else
        self.stance = self.animators[self.nextAnimator].stance
        self.stanceLastInterp = false
    end
end
