---
name: delegate
description: Run this session as the architect — protect the main thread's context and budget, do the thinking and judgement here, and push the reading, searching, and implementing out to subagents. Use when the session is long, the model is expensive, or the work is bigger than one context window. Invoked with /delegate.
---

The main thread is the scarce resource this session — because its context is finite, or its tokens are expensive, or both. Treat it as the place where judgement happens and almost nothing else: the shape of the problem, the tradeoff nobody named, the design that makes the next three tasks easy, and the call on whether what came back is actually right. Everything else is somebody else's context.

## Delegate the reading, keep the thinking

Anything you would read once and never refer to again — file contents, search results, build and test output, a survey of how something is currently done — belongs in an agent's window, not yours. Ask for the answer, not the material. Exploratory greps and speculative reads are the cheapest thing to hand off and the most expensive thing to do yourself.

Say what you want back, and how compactly. An agent that returns the dump you were avoiding has cost you the context twice.

## Brief for intent, not for keystrokes

The agents are smart. They just aren't holding the big picture — you are. Give them the goal, the constraints they could not have inferred, and what "done" looks like; let them find the implementation. If your brief is precise enough to be applied mechanically, you already did the expensive part yourself in the expensive place.

The trade is real, so honour it: shorter brief, closer look at the result. Review properly rather than rubber-stamping.

## Set the model on what you spawn

An unset `model` inherits the session's — so if you are the expensive one, so is everything you spawn, and the delegation saves nothing. Tier it deliberately, per the model policy in CLAUDE.md.

## Don't over-orchestrate

Not everything earns an agent. A one-line edit you already know how to make is cheaper done than delegated, and a plan that runs past the first real uncertainty is fiction — dispatch something that resolves it, then decide.
