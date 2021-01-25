<?php

declare(strict_types=1);

namespace Spec\VPNMinute\Core\Fetcher;

use PhpSpec\ObjectBehavior;
use VPNMinute\Core\Assembly\AssemblyDeliberationCacheProxy;
use VPNMinute\Core\Bag\CanBeFetchedBag;
use VPNMinute\Core\CanBeFetched;
use VPNMinute\Core\Exception\InternalConfigurationException;
use VPNMinute\Core\Fetcher\CanFetch;
use VPNMinute\Core\Fetcher\Fetcher;

class FetcherSpec extends ObjectBehavior
{
    public const DELIBERATION = ['test'];

    public function let(AssemblyDeliberationCacheProxy $assemblyDeliberationCacheProxy, CanBeFetchedBag $canBeFetchedBag, CanBeFetched $canBeFetched)
    {
        $assemblyDeliberationCacheProxy->getDeliberation([])->willReturn(self::DELIBERATION);
        $canBeFetchedBag->contain('test')->willReturn(true);
        $canBeFetchedBag->get('test')->willReturn($canBeFetched);

        $this->beConstructedWith($assemblyDeliberationCacheProxy, $canBeFetchedBag);
    }

    public function it_is_initializable()
    {
        $this->shouldHaveType(Fetcher::class);
    }

    public function it_can_fetch()
    {
        $this->shouldImplement(CanFetch::class);
    }

    public function it_fetches_a_can_be_fetched_object($canBeFetched)
    {
        $this->get()->shouldReturn($canBeFetched);
        $this->getWhenAvailable()->shouldReturn($canBeFetched);
    }

    public function it_returns_whether_or_not_the_can_be_fetched_object_is_available($canBeFetchedBag)
    {
        $this->isAvailable()->shouldReturn(true);

        $canBeFetchedBag->contain('test')->willReturn(false);

        $this->isAvailable()->shouldReturn(false);
    }

    public function it_returns_null_when_trying_to_get_can_be_fetched_object_gracefully_if_it_does_not_exists($assemblyDeliberationCacheProxy)
    {
        $assemblyDeliberationCacheProxy->getDeliberation([])->willReturn([]);

        $this->getWhenAvailable()->shouldReturn(null);
    }

    public function it_throws_an_exception_when_trying_to_get_can_be_fetch_object_if_it_does_not_exists($canBeFetchedBag)
    {
        $canBeFetchedBag->get('test')->willReturn(null);

        $this->shouldThrow(InternalConfigurationException::class)->during('get');
    }
}
