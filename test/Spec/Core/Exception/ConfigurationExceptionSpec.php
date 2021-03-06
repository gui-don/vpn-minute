<?php

declare(strict_types=1);

namespace Spec\VPNMinute\Core\Exception;

use PhpSpec\ObjectBehavior;
use VPNMinute\Core\Exception\ConfigurationException;
use VPNMinute\Core\Exception\Main\UserException;

class ConfigurationExceptionSpec extends ObjectBehavior
{
    public function it_is_initializable()
    {
        $this->shouldHaveType(ConfigurationException::class);
    }

    public function it_is_an_exception()
    {
        $this->shouldHaveType(\Exception::class);
    }

    public function it_is_an_user_exception()
    {
        $this->shouldHaveType(UserException::class);
    }

    public function it_is_throwable()
    {
        $this->shouldImplement(\Throwable::class);
    }
}
