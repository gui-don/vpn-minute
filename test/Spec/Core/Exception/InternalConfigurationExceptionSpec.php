<?php

declare(strict_types=1);

namespace Spec\VPNMinute\Core\Exception;

use PhpSpec\ObjectBehavior;
use VPNMinute\Core\Exception\InternalConfigurationException;
use VPNMinute\Core\Exception\Main\DeveloperException;

class InternalConfigurationExceptionSpec extends ObjectBehavior
{
    public function it_is_initializable()
    {
        $this->shouldBeAnInstanceOf(InternalConfigurationException::class);
    }

    public function it_is_an_exception()
    {
        $this->shouldHaveType(\Exception::class);
    }

    public function it_is_an_developer_exception()
    {
        $this->shouldHaveType(DeveloperException::class);
    }

    public function it_is_throwable()
    {
        $this->shouldImplement(\Throwable::class);
    }
}
