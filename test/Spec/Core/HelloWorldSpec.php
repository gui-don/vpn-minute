<?php

namespace Spec\VPNMinute\Core;

use PhpSpec\ObjectBehavior;
use VPNMinute\Core\HelloWorld;

class HelloWorldSpec extends ObjectBehavior
{
    function it_is_initializable()
    {
        $this->shouldHaveType(HelloWorld::class);
    }
}
