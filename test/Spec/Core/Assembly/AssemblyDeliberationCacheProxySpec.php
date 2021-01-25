<?php

declare(strict_types=1);

namespace Spec\VPNMinute\Core\Assembly;

use PhpSpec\ObjectBehavior;
use VPNMinute\Core\Assembly\AssemblyDeliberationCacheProxy;
use VPNMinute\Core\Assembly\CanDeliberate;

class AssemblyDeliberationCacheProxySpec extends ObjectBehavior
{
    public const DELIBERATION = ['test'];
    public const DATA = 'test';

    public function let(CanDeliberate $canDeliberate)
    {
        $canDeliberate->deliberate(self::DATA)->willReturn(self::DELIBERATION);

        $this->beConstructedWith($canDeliberate);
    }

    public function it_is_initializable()
    {
        $this->shouldHaveType(AssemblyDeliberationCacheProxy::class);
    }

    public function it_returns_a_deliberation()
    {
        $this->getDeliberation(self::DATA)->shouldReturn(self::DELIBERATION);
    }

    public function it_caches_the_deliberation_and_only_deliberates_once($canDeliberate)
    {
        $canDeliberate->deliberate(self::DATA)->shouldBeCalledTimes(1);

        $this->getDeliberation(self::DATA)->shouldReturn(self::DELIBERATION);
        $this->getDeliberation(self::DATA)->shouldReturn(self::DELIBERATION);
        $this->getDeliberation(self::DATA)->shouldReturn(self::DELIBERATION);
    }
}
