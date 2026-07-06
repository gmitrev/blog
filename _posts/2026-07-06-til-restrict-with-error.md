---
layout: post
title: "TIL: :restrict_with_error"
date: 2026-07-06 23:52 +0300
categories: rails
published: true
---

I've been using Rails for 15+ years and I still find useful stuff that I didn't know about.

This week, my discovery is the `restrict_with_error` option for the `has_one` and `has_many`
`:dependent` setting.

## Example

I developed a tiny workout tracking application which has an `Exercise` model. This is stuff like
"Squat" or "Deadlift". Every workout session consists of multiple `WorkoutExercise` objects,
which record a concrete session of that `Exercise` being used in a workout.


```rb
class WorkoutExercise < ApplicationRecord
  belongs_to :workout

  has_many :sets # and sets have reps
end

```

The question is what happens when I decide to delete an `Exercise`. Previously, I would manually
write a `before_destroy` callback to check if an `Exercise` has been used in any workouts and prevent
it from being deleted. Turns out this has been  baked into the `has_one`
and `has_many` methods ever since Rails 4 in 2013:

```rb
class Exercise
  has_many :workout_exercises, dependent: :restrict_with_error
  # ...
end
```

With this, attempting to delete an exercise that is already referenced by exiting Workouts shows a nice error on the `exercise` object:

```rb
e = Exercise.find(1)
# => #<Exercise:0x0000000109d4ded8>

e.name
# => "Squat"

e.destroy
# => false

e.errors
# => #<ActiveModel::Errors [#<ActiveModel::Error attribute=base, type=restrict_dependent_destroy.has_many, options={:record=>"workout exercises"}>]>

e.errors.full_messages
# => ["Cannot delete record because dependent workout exercises exist"]
```

This is much nicer and elegant than having to roll a custom validation.

There's also `:restrict_with_exception`, which raises an exception instead of adding validation
errors to the object.
